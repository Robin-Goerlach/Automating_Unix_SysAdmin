#!/usr/bin/python3 -I
"""Review monitoring prerequisites and offline SMART/sensor captures; no device probing."""
import argparse
import importlib.util
import json
import math
import os
from pathlib import Path
import re
import stat
import subprocess
import sys

HERE = Path(__file__).resolve().parent
PACKAGES = ('smartmontools', 'lm-sensors', 'rng-tools', 'haveged', 'snmp', 'snmpd', 'monit')
CHECKS = ('client-smart', 'client-temp')
LIMIT = 1024 * 1024


def load(name):
    sys.dont_write_bytecode = True
    spec = importlib.util.spec_from_file_location(name, HERE / (name + '.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def unique_pairs(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError('duplicate JSON field')
        result[key] = value
    return result


def reject_constant(value):
    raise ValueError('invalid JSON constant')


def read_capture(path):
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    with os.fdopen(fd, 'rb') as stream:
        info = os.fstat(fd)
        if not stat.S_ISREG(info.st_mode) or info.st_size > LIMIT:
            raise ValueError('unsafe capture')
        data = stream.read(LIMIT + 1)
        after = os.fstat(fd)
        if len(data) != info.st_size or (info.st_mtime_ns, info.st_ctime_ns) != (after.st_mtime_ns, after.st_ctime_ns):
            raise ValueError('capture changed')
    return json.loads(data, object_pairs_hook=unique_pairs, parse_constant=reject_constant)


def smart_result(data):
    """Single captured device; conservative interpretation of smartctl JSON."""
    if not isinstance(data, dict) or not isinstance(data.get('smartctl'), dict):
        raise ValueError('invalid smartctl capture')
    rc = data['smartctl'].get('exit_status')
    if type(rc) is not int or not 0 <= rc <= 255:
        raise ValueError('invalid smartctl exit status')
    status = data.get('smart_status', {})
    if not isinstance(status, dict) or ('passed' in status and type(status['passed']) is not bool):
        raise ValueError('invalid SMART health field')
    device = data.get('device', {})
    if not isinstance(device, dict):
        raise ValueError('invalid SMART device field')
    if device.get('protocol') != 'ATA':
        return 'purple', 'offline SMART capture protocol not supported'
    if status.get('passed') is False or rc & 24:
        return 'red', 'offline ATA SMART capture reports current failure'
    if rc & 7:
        return 'purple', 'offline SMART capture has command or device errors'
    if rc & 224:
        return 'yellow', 'offline SMART capture requires historical or log review'
    if status.get('passed') is True:
        return 'green', 'offline SMART capture reports pass for one device'
    return 'purple', 'offline SMART health field missing'


def numeric(value):
    if type(value) not in (int, float) or not -1000 <= value <= 1000 or not math.isfinite(value):
        raise ValueError('invalid sensor value')
    return value


def sensor_result(data):
    """Evaluate only tempN_input and explicit tempN_max/crit fields from sensors -j."""
    if not isinstance(data, dict):
        raise ValueError('invalid sensors capture')
    count = unknown = warnings = critical = 0
    for chip in data.values():
        if not isinstance(chip, dict):
            raise ValueError('invalid sensor chip')
        for name, feature in chip.items():
            if name == 'Adapter' and isinstance(feature, str):
                continue
            if not isinstance(feature, dict):
                raise ValueError('invalid sensor feature')
            for key, value in feature.items():
                match = re.fullmatch(r'(temp[0-9]+)_input', key)
                if not match:
                    continue
                count += 1
                current = numeric(value)
                prefix = match[1]
                maximum = numeric(feature[prefix + '_max']) if prefix + '_max' in feature else None
                limit = numeric(feature[prefix + '_crit']) if prefix + '_crit' in feature else None
                if maximum is not None and limit is not None and maximum > limit:
                    raise ValueError('inconsistent temperature limits')
                if limit is not None and current >= limit:
                    critical += 1
                elif maximum is not None and current >= maximum:
                    warnings += 1
                if maximum is None or limit is None:
                    unknown += 1
    color = 'red' if critical else 'yellow' if warnings else 'purple' if not count or unknown else 'green'
    return color, 'offline temperature inputs=%d incomplete-limits=%d warning=%d critical=%d' % (count, unknown, warnings, critical)


def entropy_observation():
    try:
        with open('/proc/sys/kernel/random/entropy_avail', encoding='ascii') as stream:
            value = stream.read(32).strip()
        return value if re.fullmatch(r'[0-9]{1,10}', value) else 'UNKNOWN'
    except (OSError, ValueError):
        return 'UNKNOWN'


def main():
    p = argparse.ArgumentParser(description=__doc__, allow_abbrev=False)
    mode = p.add_mutually_exclusive_group(required=True)
    mode.add_argument('--list', action='store_true')
    mode.add_argument('--live', action='store_true')
    mode.add_argument('--capture', action='store_true')
    p.add_argument('--smart-json')
    p.add_argument('--sensors-json')
    p.add_argument('--status-preview', action='store_true')
    for key in ('hostname', 'inventory', 'roles'):
        p.add_argument('--' + key, required=True)
    a = p.parse_args()
    if os.geteuid() == 0 or (not a.capture and (a.smart_json is not None or a.sensors_json is not None or a.status_preview)):
        p.error('ordinary user required; capture options require --capture')
    try:
        module = load('plan-packages')
        profile, stages, context = module.inventory_selection(a.hostname, a.inventory, a.roles)
        results = [smart_result(read_capture(a.smart_json)) if a.smart_json is not None else ('purple', 'offline SMART capture not supplied'),
                   sensor_result(read_capture(a.sensors_json)) if a.sensors_json is not None else ('purple', 'offline temperature capture not supplied')]
        if a.status_preview:
            for check, (color, message) in zip(CHECKS, results):
                print('\t'.join((a.hostname, check, color, message + '; preview not authenticated')))
            return 3
        print('SASD-MONITORING-PLAN-1\nscope\t' + ('LOCAL_READ_ONLY' if a.live else 'CAPTURE_ONLY' if a.capture else 'POLICY_ONLY'))
        print('profile\t' + profile + '\ninventory-host\t' + a.hostname)
        print('inventory-plan-sha256\t' + context['client-plan'])
        selected = {name for names in stages.values() for name in names}
        audit = load('plan-audits') if a.live else None
        for package in PACKAGES:
            print('\t'.join(('package', package, 'SELECTED' if package in selected else 'NOT_SELECTED', audit.package_state(module, package) if audit else 'NOT_RUN')))
        if a.capture:
            for check, (color, message) in zip(CHECKS, results):
                print('\t'.join(('capture', check, color, message)))
        if a.live:
            print('entropy-available-bits\t' + entropy_observation())
        print('device-coverage\tNOT_VERIFIED\nrng-health\tNOT_VERIFIED\ncentral-registration\tNOT_APPROVED')
        print('runtime-identity\tNOT_VERIFIED\nmonitoring-apply\tNOT_AUTHORIZED')
        return 0 if a.list else 3
    except (OSError, ValueError, subprocess.SubprocessError, RecursionError):
        print('plan-monitoring: invalid or unavailable input', file=sys.stderr)
        return 2


if __name__ == '__main__':
    sys.exit(main())
