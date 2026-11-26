#!/usr/bin/python3 -I
"""Review NSS configuration and directory-client prerequisites without remote lookups."""
import argparse
import importlib.util
import os
from pathlib import Path
import re
import subprocess
import sys

HERE = Path(__file__).resolve().parent
DATABASES = ('passwd', 'group', 'shadow', 'gshadow', 'initgroups', 'hosts', 'netgroup',
             'passwd_compat', 'group_compat', 'shadow_compat')
SERVICES = {'files', 'compat', 'nis', 'nisplus', 'ldap', 'sss', 'winbind', 'systemd',
            'dns', 'resolve', 'myhostname', 'mymachines', 'mdns', 'mdns4', 'mdns6',
            'mdns_minimal', 'mdns4_minimal', 'mdns6_minimal', 'db', 'hesiod', 'wins'}
DIRECTORY = {'nis', 'nisplus', 'ldap', 'sss', 'winbind', 'compat'}
PACKAGES = ('libnss-nis', 'ypbind-mt', 'yp-tools', 'libnss-ldapd', 'libpam-ldapd',
            'nslcd', 'sssd', 'sssd-ldap', 'sssd-ad', 'libnss-sss', 'libpam-sss',
            'realmd', 'adcli', 'winbind', 'libnss-winbind')
PATHS = ('/etc/nsswitch.conf', '/etc/yp.conf', '/etc/defaultdomain', '/etc/nslcd.conf',
         '/etc/ldap/ldap.conf', '/etc/sssd/sssd.conf', '/etc/krb5.conf', '/etc/samba/smb.conf')


def load(name):
    sys.dont_write_bytecode = True
    spec = importlib.util.spec_from_file_location(name, HERE / (name + '.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def parse_nss(text):
    """Recognize source/action structure, not glibc execution semantics."""
    rows = {}
    for raw in text.splitlines():
        line = raw.split('#', 1)[0].strip()
        if not line:
            continue
        name, sep, body = line.partition(':')
        if not sep or not re.fullmatch(r'[a-z][a-z0-9_]*', name.strip()) or name.strip() in rows:
            raise ValueError('invalid or duplicate NSS database')
        name = name.strip()
        tokens = re.findall(r'\[[^\[\]]*\]|[^\s\[\]]+|[\[\]]', body)
        sources = []
        for token in tokens:
            if token.startswith('['):
                if not sources or not token.endswith(']'):
                    raise ValueError('action without source')
                actions = token[1:-1].split()
                if not actions or any(not re.fullmatch(r'!?(?:SUCCESS|NOTFOUND|UNAVAIL|TRYAGAIN)=(?:return|continue|merge)', item, re.I) for item in actions):
                    raise ValueError('unsupported NSS action')
                sources[-1][1].extend(actions)
            elif re.fullmatch(r'[a-zA-Z0-9_][a-zA-Z0-9_-]*', token):
                sources.append((token, []))
            else:
                raise ValueError('invalid NSS source')
        if not sources:
            raise ValueError('empty NSS database')
        rows[name] = sources
    if not rows:
        raise ValueError('empty NSS configuration')
    return rows


def summarize(rows):
    result = []
    for name in DATABASES:
        if name not in rows:
            result.append((name, 'NOT_EXPLICIT', '-', '0'))
            continue
        sources = [source for source, _ in rows[name]]
        known = [source if source in SERVICES else 'OTHER' for source in sources]
        actions = sum(len(items) for _, items in rows[name])
        if len(set(sources)) != len(sources) or 'OTHER' in known or actions:
            state = 'REVIEW_REQUIRED'
        elif name.endswith('_compat') or name == 'netgroup':
            state = 'REVIEW_REQUIRED' if set(sources) & DIRECTORY else 'OBSERVED'
        elif sources[0] != 'files':
            state = 'LOCAL_FIRST_NOT_EXPLICIT'
        elif set(sources) & DIRECTORY:
            state = 'DIRECTORY_REVIEW'
        else:
            state = 'LOCAL_FIRST_OBSERVED'
        result.append((name, state, ','.join(known), str(actions)))
    return result


def main():
    p = argparse.ArgumentParser(description=__doc__, allow_abbrev=False)
    mode = p.add_mutually_exclusive_group(required=True)
    mode.add_argument('--list', action='store_true')
    mode.add_argument('--live', action='store_true')
    mode.add_argument('--nss-capture')
    for key in ('hostname', 'inventory', 'roles'):
        p.add_argument('--' + key, required=True)
    a = p.parse_args()
    if os.geteuid() == 0:
        p.error('ordinary user required')
    try:
        module = load('plan-packages')
        profile, stages, context = module.inventory_selection(a.hostname, a.inventory, a.roles)
        rows = None if a.list else parse_nss(load('plan-security').read_input('/etc/nsswitch.conf' if a.live else a.nss_capture))
        selected = {name for names in stages.values() for name in names}
        audit = load('plan-audits') if a.live else None
        observer = load('plan-shell').observe if a.live else None
        print('SASD-DIRECTORY-PLAN-1\nscope\t' + ('LOCAL_READ_ONLY' if a.live else 'POLICY_ONLY' if a.list else 'CAPTURE_ONLY'))
        print('profile\t' + profile + '\ninventory-host\t' + a.hostname)
        print('inventory-plan-sha256\t' + context['client-plan'])
        for package in PACKAGES:
            print('\t'.join(('package', package, 'SELECTED' if package in selected else 'NOT_SELECTED', audit.package_state(module, package) if audit else 'NOT_RUN')))
        for row in summarize(rows) if rows is not None else []:
            print('\t'.join(('nss', *row)))
        for path in PATHS:
            print('metadata\t' + path + '\t' + (observer(Path('/'), path) if observer else 'NOT_RUN'))
        print('remote-lookup\tNOT_RUN\nauthentication\tNOT_VERIFIED\ndomain-join\tNOT_RUN')
        print('runtime-identity\tNOT_VERIFIED\ndirectory-apply\tNOT_AUTHORIZED')
        return 0 if a.list else 3
    except (OSError, ValueError, subprocess.SubprocessError):
        print('plan-directory: invalid or unavailable input', file=sys.stderr)
        return 2


if __name__ == '__main__':
    sys.exit(main())
