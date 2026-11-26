#!/usr/bin/python3 -I
"""Bounded network configuration fixture; never activate networking or firewall."""
import hashlib
import importlib.util
import ipaddress
import json
import os
from pathlib import Path
import re
import sys

HERE = Path(__file__).resolve().parent
FORMAT = 'SASD-NETWORK-FIXTURE-1'
PREFIX = 'sasd-network-lab'
MARKER = '.sasd-network-fixture'
LABEL = 'NETWORK'
DIRECTORIES = ('apt', 'apt/sources.list.d', 'apt/apt.conf.d', 'sasd-network')
PROFILES = ('baseline', 'workstation', 'laptop', 'server')
NAMES = ('hosts', 'apt/sources.list.d/sasd-debian.sources',
         'apt/apt.conf.d/60-sasd-proxy', 'sasd-network/firewall-policy.json')

sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('fixture_config', HERE / 'fixture-config.py')
engine = importlib.util.module_from_spec(spec)
spec.loader.exec_module(engine)


def text(value):
    if not isinstance(value, str) or len(value) > 65536:
        raise ValueError('invalid configuration text')
    data = value.encode('ascii')
    if any(c < 32 and c not in (9, 10) or c == 127 for c in data):
        raise ValueError('invalid configuration bytes')
    if value and not value.endswith('\n'):
        raise ValueError('final newline required')
    return value


def managed(original, desired):
    if original not in ('', desired):
        raise ValueError('existing managed configuration requires review')
    return desired


def hosts(original, records, host, expected, comms, network):
    if not isinstance(records, list) or len(records) > 64:
        raise ValueError('invalid site hosts list')
    if not records:
        return original
    known = {}
    for line in original.splitlines():
        fields = line.split('#', 1)[0].split()
        if not fields:
            continue
        if len(fields) < 2:
            raise ValueError('invalid existing hosts row')
        address = str(ipaddress.ip_address(fields[0]))
        for name in fields[1:]:
            if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.-]{0,252}', name):
                raise ValueError('unsupported existing host name')
            key = name.lower().rstrip('.')
            if not key or (key in known and known[key] != address):
                raise ValueError('conflicting existing hosts name')
            known[key] = address
    # Debian may intentionally use 127.0.1.1 for its own host; preserve it.
    # New site records must never claim the client identity or its short name.
    protected = {'localhost', 'localhost.localdomain', host, host.split('.')[0]}
    seen = set()
    result = original
    for row in records:
        if not isinstance(row, list) or len(row) != 2 or any(not isinstance(v, str) for v in row):
            raise ValueError('invalid site host row')
        name, address = row
        comms.fqdn(name)
        address = network.ipv4(address)
        if name in protected or name in seen or address == expected:
            raise ValueError('protected client identity or duplicate host')
        seen.add(name)
        if name in known:
            if known[name] != address:
                raise ValueError('existing host mapping differs')
        else:
            result += address + '\t' + name + '\n'
            known[name] = address
    return result


def apt_source(original, choice, network):
    if choice is None:
        return original
    if (not isinstance(choice, dict) or set(choice) != {'release', 'keyring_present', 'other_sources'} or
            not isinstance(choice['release'], str) or choice['keyring_present'] is not True or
            not isinstance(choice['other_sources'], dict) or len(choice['other_sources']) > 64):
        raise ValueError('explicit Debian release and modeled keyring required')
    # The caller supplies a complete synthetic capture of other source files.
    # Conservative first-install scope: no other active or unparsed source.
    for name, contents in choice['other_sources'].items():
        if (not re.fullmatch(r'sources\.list|sources\.list\.d/[A-Za-z0-9_.-]+\.(?:list|sources)', name) or
                name == 'sources.list.d/sasd-debian.sources' or
                any(line.strip() and not line.lstrip().startswith('#') for line in text(contents).splitlines())):
            raise ValueError('other APT sources need separate review')
    return managed(original, network.apt_candidate(choice['release']))


def apt_proxy(original, choice, comms):
    if choice is None:
        return original
    if (not isinstance(choice, dict) or set(choice) != {'host', 'port'} or
            not isinstance(choice['host'], str) or type(choice['port']) is not int or
            not 1 <= choice['port'] <= 65535):
        raise ValueError('invalid credential-free proxy')
    host = comms.fqdn(choice['host'])
    uri = 'http://%s:%d/' % (host, choice['port'])
    return managed(original, 'Acquire::http::Proxy "%s";\nAcquire::https::Proxy "%s";\n' % (uri, uri))


def firewall(original, choice, profile, packages, network, expected, tx):
    if choice is None:
        return original
    keys = {'phase', 'owners', 'addresses', 'routes', 'gateway', 'management_cidr'}
    if not isinstance(choice, dict) or set(choice) != keys or choice['phase'] not in ('stage1', 'stage2'):
        raise ValueError('invalid firewall policy')
    if choice['owners'] not in (['nftables'], ['iptables']):
        raise ValueError('exactly one modeled firewall owner required')
    if profile != 'server' or 'openssh-server' not in packages:
        raise ValueError('only server SSH management policy modeled')
    if not isinstance(choice['gateway'], str) or network.observe_network(
            choice['addresses'], choice['routes'], expected, choice['gateway'])[:2] != ('MATCH_CONFIGURED', 'MATCH_CONFIGURED'):
        raise ValueError('ambiguous or mismatching IPv4 configuration')
    cidr = choice['management_cidr']
    if not isinstance(cidr, str):
        raise ValueError('explicit IPv4 management network required')
    subnet = ipaddress.IPv4Network(cidr, strict=True)
    if (str(subnet) != cidr or subnet.prefixlen < 24 or
            subnet.overlaps(ipaddress.IPv4Network('127.0.0.0/8')) or
            subnet.overlaps(ipaddress.IPv4Network('224.0.0.0/3')) or
            subnet.overlaps(ipaddress.IPv4Network('0.0.0.0/8')) or
            subnet.overlaps(ipaddress.IPv4Network('169.254.0.0/16'))):
        raise ValueError('management source outside narrow IPv4 model')
    # A policy record, NOT an nft/iptables ruleset or packet evaluator.
    desired = {'format': 'SASD-FIREWALL-POLICY-1', 'phase': choice['phase'],
               'backend': choice['owners'][0], 'ipv4': expected,
               'gateway': choice['gateway'], 'management_cidr': cidr,
               'management_tcp_port': 22, 'inbound': 'REVIEW_DEFAULT_DENY',
               'established': 'PRESERVE', 'loopback': 'PRESERVE',
               'outbound': 'REVIEW_REQUIRED', 'ipv6': 'KEEP_AND_REVIEW',
               'activation': 'NOT_AUTHORIZED'}
    output = tx.encoded(desired).decode('ascii')
    if not original and choice['phase'] != 'stage1':
        raise ValueError('stage1 policy required before stage2')
    if original and original != output:
        # Only the exact same policy can advance from stage1 to stage2.
        earlier = dict(desired, phase='stage1')
        if choice['phase'] != 'stage2' or original != tx.encoded(earlier).decode('ascii'):
            raise ValueError('existing firewall policy differs; separate review')
    return output


def model(request, host, profile, stages, context, network, comms, tx):
    keys = {'original', 'hosts', 'apt', 'proxy', 'firewall'}
    if not isinstance(request, dict) or set(request) != keys:
        raise ValueError('invalid network request')
    original = request['original']
    if not isinstance(original, dict) or set(original) != set(NAMES):
        raise ValueError('invalid network target set')
    original = {name: text(value) for name, value in original.items()}
    expected = network.ipv4(context['host'][2])
    packages = {name for names in stages.values() for name in names}
    result = {
        NAMES[0]: hosts(original[NAMES[0]], request['hosts'], host, expected, comms, network),
        NAMES[1]: apt_source(original[NAMES[1]], request['apt'], network),
        NAMES[2]: apt_proxy(original[NAMES[2]], request['proxy'], comms),
        NAMES[3]: firewall(original[NAMES[3]], request['firewall'], profile, packages, network, expected, tx),
    }
    if not request['hosts'] and all(request[k] is None for k in ('apt', 'proxy', 'firewall')):
        raise ValueError('no explicit network operation')
    return {name: text(value).encode('ascii') for name, value in result.items()}


def prepare(root, host, profile, stages, tx, context):
    data, mode = tx.read_file(root / 'request.json', os.geteuid(), 65536, target=True)
    if mode != 0o600:
        raise ValueError('network request must be private')
    request = json.loads(data, object_pairs_hook=tx.unique_pairs)
    result = model(request, host, profile, stages, context, engine.load('plan-network'),
                   engine.load('plan-communications'), tx)
    original = {name: {'data': value.encode('ascii').hex(), 'mode': 0o644}
                for name, value in request['original'].items()}
    return {'request-sha256': hashlib.sha256(data).hexdigest()}, original, result


if __name__ == '__main__':
    sys.exit(engine.run(sys.modules[__name__]))
