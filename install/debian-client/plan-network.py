#!/usr/bin/python3 -I
"""Review IPv4 observations and generate a separate Debian APT source candidate."""
import argparse
import importlib.util
import ipaddress
import json
import os
from pathlib import Path
import platform
import re
import subprocess
import sys

HERE = Path(__file__).resolve().parent
RELEASES = {'12': 'bookworm', '13': 'trixie'}


def load(name):
    sys.dont_write_bytecode = True
    spec = importlib.util.spec_from_file_location(name, HERE / (name + '.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def ipv4(value):
    if not isinstance(value, str):
        raise ValueError('expected IPv4 string')
    address = ipaddress.IPv4Address(value)
    if address.is_unspecified or address.is_multicast or address.is_loopback or int(address) == 4294967295:
        raise ValueError('invalid unicast IPv4')
    return str(address)


def observe_network(addresses, routes, expected, gateway=None):
    """No connectivity claim: compare configured global IPv4 and main default route."""
    expected = ipv4(expected)
    if gateway is not None:
        gateway = ipv4(gateway)
    if not isinstance(addresses, list) or not isinstance(routes, list):
        raise ValueError('expected ip JSON arrays')
    matches = []
    names = set()
    for link in addresses:
        if not isinstance(link, dict):
            raise ValueError('invalid link row')
        name, flags, records = link.get('ifname'), link.get('flags'), link.get('addr_info')
        if (not isinstance(name, str) or not re.fullmatch(r'[A-Za-z0-9_.:@-]{1,64}', name) or name in names or
                not isinstance(flags, list) or not all(isinstance(v, str) for v in flags) or not isinstance(records, list)):
            raise ValueError('invalid interface observation')
        names.add(name)
        for row in records:
            if not isinstance(row, dict) or row.get('family') != 'inet':
                raise ValueError('invalid IPv4 observation')
            local = row.get('local')
            if not isinstance(local, str) or str(ipaddress.IPv4Address(local)) != local or type(row.get('prefixlen')) is not int or not 0 <= row['prefixlen'] <= 32:
                raise ValueError('invalid IPv4 address record')
            if local == expected:
                matches.append((name, 'UP' in flags and row.get('scope') == 'global'))
    address_state = 'MISSING' if not matches else 'AMBIGUOUS' if len(matches) != 1 else 'MATCH_CONFIGURED' if matches[0][1] else 'REVIEW_REQUIRED'
    defaults = []
    for row in routes:
        if not isinstance(row, dict) or row.get('dst') != 'default':
            raise ValueError('invalid default route observation')
        defaults.append(row)
    if gateway is None:
        route_state = 'NOT_REQUESTED'
    elif len(defaults) != 1:
        route_state = 'MISSING' if not defaults else 'AMBIGUOUS'
    else:
        row = defaults[0]
        if 'nexthops' in row or 'multipath' in row or row.get('type', 'unicast') != 'unicast' or row.get('table', 'main') not in ('main', 254):
            route_state = 'REVIEW_REQUIRED'
        elif address_state != 'MATCH_CONFIGURED':
            route_state = 'REVIEW_REQUIRED'
        else:
            route_state = 'MATCH_CONFIGURED' if row.get('gateway') == gateway and row.get('dev') == matches[0][0] else 'MISMATCH'
    return address_state, route_state, len(defaults)


def apt_candidate(release):
    if release not in RELEASES:
        raise ValueError('unsupported Debian release')
    codename = RELEASES[release]
    key = 'Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg'
    return ('Types: deb\nURIs: https://deb.debian.org/debian\nSuites: ' + codename + ' ' + codename + '-updates\nComponents: main\n' + key + '\n\nTypes: deb\nURIs: https://security.debian.org/debian-security\nSuites: ' + codename + '-security\nComponents: main\n' + key + '\n')


def main():
    p = argparse.ArgumentParser(description=__doc__, allow_abbrev=False)
    mode = p.add_mutually_exclusive_group(required=True)
    mode.add_argument('--list', action='store_true')
    mode.add_argument('--live', action='store_true')
    mode.add_argument('--capture', action='store_true')
    for key in ('hostname', 'inventory', 'roles'):
        p.add_argument('--' + key, required=True)
    p.add_argument('--addresses')
    p.add_argument('--routes')
    p.add_argument('--gateway')
    p.add_argument('--release', choices=tuple(RELEASES))
    a = p.parse_args()
    if os.geteuid() == 0 or (a.capture != bool(a.addresses and a.routes)) or (not a.capture and (a.addresses is not None or a.routes is not None)) or (a.live and a.release is not None) or (a.list and a.gateway is not None):
        p.error('ordinary user required; capture requires both files; live release is detected')
    try:
        module = load('plan-packages')
        profile, _, context = module.inventory_selection(a.hostname, a.inventory, a.roles)
        expected = ipv4(context['host'][2])
        release = a.release
        observation = None
        if a.capture:
            reader = load('plan-monitoring').read_capture
            observation = observe_network(reader(a.addresses), reader(a.routes), expected, a.gateway)
        elif a.live:
            data = []
            for args in (('address', 'show'), ('route', 'show', 'table', 'main', 'default')):
                r = module.command('/usr/sbin/ip', '-j', '-4', *args)
                if r.returncode or r.stderr.strip() or len(r.stdout) > 1024 * 1024:
                    raise ValueError('ip observation unavailable')
                data.append(json.loads(r.stdout))
            observation = observe_network(*data, expected, a.gateway)
            osinfo = platform.freedesktop_os_release()
            release = osinfo.get('VERSION_ID') if osinfo.get('ID') == 'debian' else None
        candidate = apt_candidate(release) if release in RELEASES else None
    except (OSError, ValueError, subprocess.SubprocessError, RecursionError):
        print('plan-network: invalid or unavailable input', file=sys.stderr)
        return 2
    print('SASD-NETWORK-PLAN-1\nscope\t' + ('LOCAL_READ_ONLY' if a.live else 'CAPTURE_ONLY' if a.capture else 'POLICY_ONLY'))
    print('profile\t' + profile + '\ninventory-host\t' + a.hostname)
    print('inventory-plan-sha256\t' + context['client-plan'])
    if observation is not None:
        print('ipv4\t%s\ndefault-route\t%s\ndefault-route-count\t%d' % observation)
    else:
        print('ipv4\tNOT_RUN\ndefault-route\tNOT_RUN')
    print('apt-source-candidate\t' + ('REVIEW_REQUIRED' if candidate else 'RELEASE_INPUT_REQUIRED'))
    for line in candidate.splitlines() if candidate else []:
        print('deb822\t' + line)
    print('existing-apt-sources\tNOT_INSPECTED\napt-signature\tNOT_VERIFIED\nconnectivity\tNOT_TESTED')
    print('firewall-effective\tNOT_VERIFIED\nruntime-identity\tNOT_VERIFIED\nnetwork-apply\tNOT_AUTHORIZED')
    return 0 if a.list else 3


if __name__ == '__main__':
    sys.exit(main())
