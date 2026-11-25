#!/usr/bin/python3 -I
"""Review SSH public pins, captured SFTP configuration and explicit mail policy offline."""
import argparse
import base64
import hashlib
import importlib.util
from pathlib import Path
import re
import struct
import subprocess
import sys

HERE = Path(__file__).resolve().parent


def planner():
    sys.dont_write_bytecode = True
    spec = importlib.util.spec_from_file_location('packages', HERE / 'plan-packages.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def fqdn(value):
    if len(value) > 253 or '.' not in value or not all(
        re.fullmatch(r'[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?', part) for part in value.split('.')
    ):
        raise ValueError('expected lowercase FQDN')
    return value


def read_input(path):
    path = Path(path)
    if path.is_symlink() or not path.is_file() or path.stat().st_size > 65536:
        raise ValueError('unsafe or oversized input')
    data = path.read_bytes()
    if len(data) > 65536 or any(b < 32 and b not in (9, 10) or b >= 127 for b in data):
        raise ValueError('invalid input bytes')
    return data.decode('ascii')


def public_pins(text):
    """A deliberately narrow input format: one literal FQDN and Ed25519 public key."""
    result = []
    seen = set()
    for line in text.splitlines():
        if not line or line.startswith('#'):
            continue
        parts = line.split()
        if len(parts) != 3 or parts[1] != 'ssh-ed25519':
            raise ValueError('expected literal host and Ed25519 public key')
        host = fqdn(parts[0])
        if host in seen:
            raise ValueError('duplicate host pin')
        seen.add(host)
        try:
            blob = base64.b64decode(parts[2], validate=True)
        except ValueError:
            raise ValueError('invalid public key encoding') from None
        prefix = struct.pack('>I', 11) + b'ssh-ed25519' + struct.pack('>I', 32)
        if len(blob) != len(prefix) + 32 or not blob.startswith(prefix) or base64.b64encode(blob).decode('ascii') != parts[2]:
            raise ValueError('invalid Ed25519 public key structure')
        fp = base64.b64encode(hashlib.sha256(blob).digest()).decode('ascii').rstrip('=')
        result.append((host, 'SHA256:' + fp))
    if not result:
        raise ValueError('empty public pin list')
    return result


def sftp_result(text):
    rows = [line.split() for line in text.splitlines() if line.split()[:2] == ['subsystem', 'sftp']]
    if len(rows) != 1:
        return 'REVIEW_REQUIRED'
    if rows[0][2:] in (['internal-sftp'], ['/usr/lib/openssh/sftp-server']):
        return 'RECOGNIZED_STATIC'
    return 'REVIEW_REQUIRED'


def mail_values(relay, recipient):
    fqdn(relay)
    local, sep, domain = recipient.partition('@')
    if not sep or not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._+-]{0,63}', local):
        raise ValueError('expected one explicit external mailbox')
    fqdn(domain)
    return [('relayhost', '[' + relay + ']'), ('inet_interfaces', 'loopback-only'),
            ('mydestination', ''), ('smtp_tls_security_level', 'verify'),
            ('smtp_tls_CAfile', '/etc/ssl/certs/ca-certificates.crt'),
            ('smtpd_banner', '$myhostname ESMTP'), ('root-alias', recipient)]


def main():
    p = argparse.ArgumentParser(description=__doc__, allow_abbrev=False)
    for key in ('hostname', 'inventory', 'roles'):
        p.add_argument('--' + key, required=True)
    p.add_argument('--known-hosts')
    p.add_argument('--sshd-effective')
    p.add_argument('--relay')
    p.add_argument('--root-alias')
    a = p.parse_args()
    if (a.relay is None) != (a.root_alias is None):
        p.error('relay and root alias must be supplied together')
    try:
        module = planner()
        profile, stages, context = module.inventory_selection(a.hostname, a.inventory, a.roles)
        packages = {name for names in stages.values() for name in names}
        pins = public_pins(read_input(a.known_hosts)) if a.known_hosts is not None else None
        sftp = sftp_result(read_input(a.sshd_effective)) if a.sshd_effective is not None else 'NOT_RUN'
        mail = mail_values(a.relay, a.root_alias) if a.relay is not None else None
        if mail and (a.relay == a.hostname or a.root_alias.rsplit('@', 1)[1] == a.hostname):
            raise ValueError('local relay or alias loop')
    except (OSError, ValueError, subprocess.SubprocessError) as exc:
        print('plan-communications: ' + str(exc), file=sys.stderr)
        return 2
    print('SASD-COMMUNICATIONS-PLAN-1\nscope\tOFFLINE_REVIEW_ONLY')
    print('profile\t' + profile + '\ninventory-host\t' + a.hostname)
    print('inventory-plan-sha256\t' + context['client-plan'])
    print('runtime-identity\tNOT_VERIFIED')
    for package in ('openssh-client', 'openssh-server', 'openssh-sftp-server', 'postfix'):
        print('package\t' + package + '\t' + ('SELECTED' if package in packages else 'NOT_SELECTED'))
    print('known-hosts\t' + ('REVIEW_PINS' if pins else 'INPUT_REQUIRED'))
    for host, fp in pins or []:
        print('pin\t' + host + '\t' + fp)
    print('sftp\t' + sftp + '\nssh-access\tNOT_TESTED')
    print('mail\t' + ('REVIEW_REQUIRED' if mail else 'INPUT_REQUIRED'))
    for key, value in mail or []:
        print('mail-candidate\t' + key + '\t' + value)
    print('communications-apply\tNOT_AUTHORIZED')
    return 3


if __name__ == '__main__':
    sys.exit(main())
