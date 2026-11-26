#!/usr/bin/python3 -I
"""Review boot, kernel and recovery prerequisites without changing the system."""
import argparse
import importlib.util
import os
from pathlib import Path
import re
import subprocess
import sys

HERE = Path(__file__).resolve().parent
PARAMETERS = ('ipv6.disable', 'selinux', 'enforcing')
MODULES = ('firewire_ohci', 'firewire_core', 'usb_storage')
PACKAGES = ('grub-pc', 'grub-efi-amd64', 'grub-efi-amd64-signed', 'selinux-basics',
            'selinux-policy-default', 'policycoreutils', 'usbguard', 'rear')
PATHS = ('/etc/default/grub', '/etc/grub.d/40_custom', '/boot/grub/grub.cfg',
         '/etc/modprobe.d', '/etc/selinux/config', '/etc/usbguard/rules.conf',
         '/etc/rear/local.conf')
LIVE = {'cmdline': '/proc/cmdline', 'modules': '/proc/modules',
        'ipv6-all': '/proc/sys/net/ipv6/conf/all/disable_ipv6',
        'ipv6-default': '/proc/sys/net/ipv6/conf/default/disable_ipv6',
        'lsm': '/sys/kernel/security/lsm', 'enforce': '/sys/fs/selinux/enforce'}
LIMIT = 1024 * 1024


def load(name):
    sys.dont_write_bytecode = True
    spec = importlib.util.spec_from_file_location(name, HERE / (name + '.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def parameters(text):
    # Intentionally refuse quoted/escaped syntax rather than misparse kernel arguments.
    if not text.strip() or len(text.splitlines()) != 1 or any(c in text for c in ('"', "'", '\\')):
        raise ValueError('unsupported kernel command line')
    result = []
    for name in PARAMETERS:
        values = [token.partition('=')[2] for token in text.split()
                  if token.partition('=')[0] == name]
        state = ('NOT_EXPLICIT' if not values else 'AMBIGUOUS' if len(values) != 1
                 else values[0] if values[0] in ('0', '1') else 'REVIEW_REQUIRED')
        result.append((name, state))
    return result


def modules(text):
    names = set()
    for line in text.splitlines():
        fields = line.split()
        if (len(fields) < 6 or not re.fullmatch(r'[A-Za-z0-9_]+', fields[0]) or
                fields[0] in names or not fields[1].isdigit() or not fields[2].isdigit()):
            raise ValueError('invalid module observation')
        names.add(fields[0])
    return [(name, 'LISTED' if name in names else 'NOT_LISTED') for name in MODULES]


def binary_state(text):
    if text is None:
        return 'UNKNOWN'
    value = text.strip()
    if value not in ('0', '1'):
        raise ValueError('invalid binary observation')
    return value


def selinux_state(lsm, enforce):
    if lsm is None:
        state = 'UNKNOWN'
    else:
        names = lsm.strip().split(',')
        if any(not re.fullmatch(r'[A-Za-z0-9_-]+', name) for name in names) or len(names) != len(set(names)):
            raise ValueError('invalid LSM observation')
        state = 'LISTED' if 'selinux' in names else 'NOT_LISTED'
    mode = binary_state(enforce)
    if state == 'NOT_LISTED' and mode != 'UNKNOWN':
        return state, 'INCONSISTENT_REVIEW'
    return state, {'0': 'PERMISSIVE_OBSERVED', '1': 'ENFORCING_OBSERVED', 'UNKNOWN': 'UNKNOWN'}[mode]


def live_read(name):
    try:
        with open(LIVE[name], 'rb') as stream:
            data = stream.read(LIMIT + 1)
    except OSError:
        return None
    if len(data) > LIMIT or any(c < 32 and c not in (9, 10) or c >= 127 for c in data):
        raise ValueError('invalid kernel observation')
    return data.decode('ascii')


def observations(read):
    cmd, mods = read('cmdline'), read('modules')
    for name, state in parameters(cmd) if cmd is not None else [(n, 'UNKNOWN') for n in PARAMETERS]:
        yield ('kernel-parameter', name, state)
    for name, state in modules(mods) if mods is not None else [(n, 'UNKNOWN') for n in MODULES]:
        yield ('module', name, state)
    for name in ('ipv6-all', 'ipv6-default'):
        yield ('kernel-setting', name, binary_state(read(name)))
    lsm, enforce = selinux_state(read('lsm'), read('enforce'))
    yield ('selinux', 'lsm', lsm)
    yield ('selinux', 'mode', enforce)


def main():
    p = argparse.ArgumentParser(description=__doc__, allow_abbrev=False)
    mode = p.add_mutually_exclusive_group(required=True)
    mode.add_argument('--list', action='store_true')
    mode.add_argument('--live', action='store_true')
    mode.add_argument('--capture')
    for key in ('hostname', 'inventory', 'roles'):
        p.add_argument('--' + key, required=True)
    a = p.parse_args()
    if os.geteuid() == 0:
        p.error('ordinary user required')
    try:
        module = load('plan-packages')
        profile, stages, context = module.inventory_selection(a.hostname, a.inventory, a.roles)
        data = []
        if a.live:
            data = list(observations(live_read))
        elif a.capture is not None:
            root = Path(a.capture)
            if not root.is_dir() or root.is_symlink():
                raise ValueError('invalid capture directory')
            reader = load('plan-security').read_input
            def capture(name):
                path = root / name
                if name not in ('cmdline', 'modules') and not path.exists() and not path.is_symlink():
                    return None
                return reader(path)
            data = list(observations(capture))
        selected = {name for names in stages.values() for name in names}
        audit = load('plan-audits') if a.live else None
        observer = load('plan-shell').observe if a.live else None
        print('SASD-RECOVERY-PLAN-1\nscope\t' + ('LOCAL_READ_ONLY' if a.live else 'POLICY_ONLY' if a.list else 'CAPTURE_ONLY'))
        print('profile\t' + profile + '\ninventory-host\t' + a.hostname)
        print('inventory-plan-sha256\t' + context['client-plan'])
        for package in PACKAGES:
            print('\t'.join(('package', package, 'SELECTED' if package in selected else 'NOT_SELECTED', audit.package_state(module, package) if audit else 'NOT_RUN')))
        for row in data:
            print('\t'.join(row))
        for path in PATHS:
            print('metadata\t' + path + '\t' + (observer(Path('/'), path) if observer else 'NOT_RUN'))
        print('grub-authentication\tNOT_VERIFIED\nblacklist-effective\tNOT_VERIFIED\nusbguard-policy\tNOT_VERIFIED')
        print('recovery-media\tNOT_CREATED\nrestore-test\tNOT_RUN\nruntime-identity\tNOT_VERIFIED\nrecovery-apply\tNOT_AUTHORIZED')
        return 0 if a.list else 3
    except (OSError, ValueError, subprocess.SubprocessError):
        print('plan-recovery: invalid or unavailable input', file=sys.stderr)
        return 2


if __name__ == '__main__':
    sys.exit(main())
