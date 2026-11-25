#!/usr/bin/python3 -I
"""Plan core services for one R2 host; optionally observe local package/unit state."""
import argparse
import importlib.util
from pathlib import Path
import os
import re
import subprocess
import sys

HERE = Path(__file__).resolve().parent


def package_planner():
    sys.dont_write_bytecode = True
    spec = importlib.util.spec_from_file_location('packages', HERE / 'plan-packages.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def service_rows(output, profile, allowed):
    lines = output.splitlines()
    if not lines or lines[0] != 'profile\tpackage\tunit\tpolicy':
        raise ValueError('invalid service policy header')
    selected = []
    seen = set()
    for line in lines[1:]:
        parts = line.split('\t')
        if len(parts) != 4:
            raise ValueError('invalid service policy row')
        labels, package, unit, policy = parts
        labels = labels.split(',')
        if (not set(labels) <= {'baseline', 'workstation', 'laptop', 'server'} or
                len(labels) != len(set(labels)) or not re.fullmatch(r'[a-z0-9][a-z0-9+.-]+', package) or
                not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.-]*\.service', unit) or policy not in allowed):
            raise ValueError('invalid service policy fields')
        if profile in labels:
            if unit in seen:
                raise ValueError('duplicate selected unit')
            seen.add(unit)
            selected.append((package, unit, policy))
    return selected


def unit_state(output):
    fields = {}
    for line in output.splitlines():
        key, sep, value = line.partition('=')
        if (not sep or key in fields or key not in ('LoadState', 'ActiveState', 'UnitFileState') or
                not re.fullmatch(r'[a-z][a-z0-9-]*', value)):
            raise ValueError('unexpected unit observation')
        fields[key] = value
    if set(fields) != {'LoadState', 'ActiveState', 'UnitFileState'}:
        raise ValueError('incomplete unit observation')
    return tuple(fields[k] for k in ('LoadState', 'ActiveState', 'UnitFileState'))


def observe(module, package, unit):
    pkg = 'UNKNOWN'
    try:
        r = module.command('/usr/bin/dpkg-query', '-W', '-f=${db:Status-Abbrev}\\t${Version}\\n', package)
        if r.returncode == 0 and not r.stderr.strip():
            pkg = module.installed_result(r.stdout)[0]
    except (OSError, ValueError, subprocess.SubprocessError):
        pass
    try:
        r = module.command('/usr/bin/systemctl', 'show', '--no-pager', '--property=LoadState,ActiveState,UnitFileState', '--', unit)
        if r.returncode or r.stderr.strip():
            raise ValueError('unit query failed')
        return (pkg, *unit_state(r.stdout))
    except (OSError, ValueError, subprocess.SubprocessError):
        return (pkg, 'UNKNOWN', 'UNKNOWN', 'UNKNOWN')


def main():
    p = argparse.ArgumentParser(description=__doc__, allow_abbrev=False)
    mode = p.add_mutually_exclusive_group(required=True)
    mode.add_argument('--list', action='store_true')
    mode.add_argument('--live', action='store_true')
    for key in ('hostname', 'inventory', 'roles'):
        p.add_argument('--' + key, required=True)
    a = p.parse_args()
    if a.live and os.geteuid() == 0:
        p.error('live observation requires an ordinary user')
    try:
        module = package_planner()
        profile, stages, context = module.inventory_selection(a.hostname, a.inventory, a.roles)
        selected = {name for names in stages.values() for name in names}
        rows = []
        for task, name, allowed in (
                ('0300', 'Services_Disable_Unneeded', {'REVIEW_DISABLE', 'KEEP_UNCHANGED'}),
                ('0710', 'Services_Activate_Required', {'REVIEW_ENABLE'})):
            r = module.command('/bin/sh', str(HERE / 'tasks' / (task + '_' + name)),
                               '--hostname=' + a.hostname, '--render')
            if r.returncode or r.stderr.strip():
                raise ValueError('service policy renderer failed')
            for package, unit, policy in service_rows(r.stdout, profile, allowed):
                rows.append((task, package, unit, policy))
        if len({row[2] for row in rows}) != len(rows):
            raise ValueError('conflicting service policy')
    except (OSError, ValueError, subprocess.SubprocessError) as exc:
        print('plan-services: ' + str(exc), file=sys.stderr)
        return 2
    print('SASD-SERVICE-PLAN-1\nscope\t' + ('LOCAL_READ_ONLY' if a.live else 'POLICY_ONLY'))
    print('profile\t' + profile + '\ninventory-host\t' + a.hostname)
    print('inventory-plan-sha256\t' + context['client-plan'])
    for label, value in sorted(context['inputs'].items()):
        print('input-sha256\t' + label + '\t' + value)
    print('runtime-identity\tNOT_VERIFIED')
    print('task\tpackage\tunit\tpolicy\tpackage-selection\tdpkg\tload\tactive\tunit-file')
    for task, package, unit, policy in rows:
        state = observe(module, package, unit) if a.live else ('NOT_RUN',) * 4
        print('\t'.join((task, package, unit, policy, 'SELECTED' if package in selected else 'NOT_SELECTED', *state)))
    print('service-apply\tNOT_AUTHORIZED')
    return 3 if a.live else 0


if __name__ == '__main__':
    sys.exit(main())
