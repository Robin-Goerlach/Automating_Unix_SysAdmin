#!/usr/bin/python3 -I
"""Review printing, configuration management, updates and logging without activating them."""
import argparse
import importlib.util
import os
from pathlib import Path
import re
import subprocess
import sys

HERE = Path(__file__).resolve().parent
UNITS = (('cups', 'cups.service'), ('cups', 'cups.socket'),
         ('puppet-agent', 'puppet.service'), ('apt', 'apt-daily.timer'),
         ('apt', 'apt-daily-upgrade.timer'), ('rsyslog', 'rsyslog.service'),
         ('syslog-ng-core', 'syslog-ng.service'))
PACKAGES = ('cups', 'cups-client', 'puppet-agent', 'puppet', 'apt',
            'unattended-upgrades', 'rsyslog', 'syslog-ng-core')
KEYS = ('Enable', 'Update-Package-Lists', 'Download-Upgradeable-Packages',
        'Unattended-Upgrade', 'AutocleanInterval')
PATHS = ('/etc/cups/cupsd.conf', '/etc/cups/printers.conf', '/etc/puppet/puppet.conf',
         '/etc/puppetlabs/puppet/puppet.conf', '/etc/apt/apt.conf.d',
         '/etc/rsyslog.conf', '/etc/rsyslog.d', '/etc/syslog-ng/syslog-ng.conf')


def load(name):
    sys.dont_write_bytecode = True
    spec = importlib.util.spec_from_file_location(name, HERE / (name + '.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def periodic(text):
    """Restricted observation of five keys in an explicit apt-config dump capture."""
    found = {key.lower(): [] for key in KEYS}
    for line in text.splitlines():
        match = re.match(r'^\s*APT::Periodic::([A-Za-z-]+)\b(.*)$', line, re.I)
        if not match or match[1].lower() not in found:
            continue
        value = re.fullmatch(r'\s+"([0-9]{1,3})";\s*', match[2])
        found[match[1].lower()].append(int(value[1]) if value else None)
    result = []
    for key in KEYS:
        values = found[key.lower()]
        limit = 1 if key == 'Enable' else 365
        state = ('NOT_EXPLICIT' if not values else 'REVIEW_REQUIRED'
                 if len(values) != 1 or values[0] is None or values[0] > limit
                 else str(values[0]))
        result.append((key, state))
    return result


def log_state(states):
    a, b = (states.get(name, 'UNKNOWN') for name in ('rsyslog.service', 'syslog-ng.service'))
    if a == b == 'active':
        return 'BOTH_ACTIVE_REVIEW'
    if a == 'active' and b == 'inactive':
        return 'RSYSLOG_ACTIVE_OBSERVED'
    if b == 'active' and a == 'inactive':
        return 'SYSLOG_NG_ACTIVE_REVIEW'
    if a == b == 'inactive':
        return 'NEITHER_ACTIVE_OBSERVED'
    return 'UNKNOWN_OR_TRANSITIONAL'


def main():
    p = argparse.ArgumentParser(description=__doc__, allow_abbrev=False)
    mode = p.add_mutually_exclusive_group(required=True)
    mode.add_argument('--list', action='store_true')
    mode.add_argument('--live', action='store_true')
    mode.add_argument('--apt-capture')
    for key in ('hostname', 'inventory', 'roles'):
        p.add_argument('--' + key, required=True)
    a = p.parse_args()
    if os.geteuid() == 0:
        p.error('ordinary user required')
    try:
        module = load('plan-packages')
        profile, stages, context = module.inventory_selection(a.hostname, a.inventory, a.roles)
        settings = periodic(load('plan-security').read_input(a.apt_capture)) if a.apt_capture is not None else []
        selected = {name for names in stages.values() for name in names}
        audit = load('plan-audits') if a.live else None
        services = load('plan-services') if a.live else None
        observer = load('plan-shell').observe if a.live else None
        print('SASD-OPERATIONS-PLAN-1\nscope\t' + ('LOCAL_READ_ONLY' if a.live else 'POLICY_ONLY' if a.list else 'CAPTURE_ONLY'))
        print('profile\t' + profile + '\ninventory-host\t' + a.hostname)
        print('inventory-plan-sha256\t' + context['client-plan'])
        for package in PACKAGES:
            print('\t'.join(('package', package, 'SELECTED' if package in selected else 'NOT_SELECTED', audit.package_state(module, package) if audit else 'NOT_RUN')))
        states = {}
        for package, unit in UNITS:
            state = services.observe(module, package, unit)[1:] if services else ('NOT_RUN',) * 3
            states[unit] = state[1]
            print('\t'.join(('unit', unit, *state)))
        print('logging-backends\t' + (log_state(states) if a.live else 'NOT_RUN'))
        for key, value in settings:
            print('\t'.join(('apt-periodic', key, value)))
        for path in PATHS:
            print('metadata\t' + path + '\t' + (observer(Path('/'), path) if observer else 'NOT_RUN'))
        print('print-queues\tNOT_VERIFIED\npuppet-catalog\tNOT_RUN\nupdate-schedule\tNOT_VERIFIED\nlog-delivery\tNOT_VERIFIED')
        print('runtime-identity\tNOT_VERIFIED\noperations-apply\tNOT_AUTHORIZED')
        return 0 if a.list else 3
    except (OSError, ValueError, subprocess.SubprocessError):
        print('plan-operations: invalid or unavailable input', file=sys.stderr)
        return 2


if __name__ == '__main__':
    sys.exit(main())
