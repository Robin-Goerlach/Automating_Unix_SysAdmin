#!/usr/bin/python3 -I
"""Review local mounts and explicit NFS candidates without mounting or probing shares."""
import argparse
import importlib.util
from pathlib import Path
import os
import platform
import re
import subprocess
import sys

HERE = Path(__file__).resolve().parent
LIMIT = 4 * 1024 * 1024


def read_text(path, live=False):
    path = Path(path)
    if not live and (path.is_symlink() or not path.is_file() or path.stat().st_size > LIMIT):
        raise ValueError('unsafe capture file')
    with path.open('rb') as stream:
        data = stream.read(LIMIT + 1)
    if len(data) > LIMIT or any(c < 32 and c not in (9, 10) or c == 127 for c in data):
        raise ValueError('invalid capture bytes')
    return data.decode('ascii')


def unescape(value):
    result = re.sub(r'\\(040|011|012|134|043)', lambda m: chr(int(m[1], 8)), value)
    if '\\' in re.sub(r'\\(040|011|012|134|043)', '', value):
        raise ValueError('unsupported path escape')
    return result


def fstab_rows(text):
    rows = []
    for line in text.splitlines():
        if not line.strip() or line.lstrip().startswith('#'):
            continue
        fields = line.split()
        if not 4 <= len(fields) <= 6 or any(not re.fullmatch(r'[0-9]+', v) for v in fields[4:]):
            raise ValueError('unsupported fstab row')
        target = unescape(fields[1])
        if not target.startswith('/') and not (fields[2] == 'swap' and target in ('none', 'swap')):
            raise ValueError('unsupported fstab target')
        opts = fields[3].split(',')
        if not all(opts):
            raise ValueError('empty fstab option')
        rows.append((target, fields[2], opts))
    return rows


def mount_rows(text):
    rows = []
    for line in text.splitlines():
        fields = line.split()
        if fields.count('-') != 1:
            raise ValueError('invalid mountinfo separator')
        cut = fields.index('-')
        if cut < 6 or len(fields) != cut + 4 or not fields[0].isdigit() or not fields[1].isdigit():
            raise ValueError('invalid mountinfo row')
        target = unescape(fields[4])
        if not target.startswith('/'):
            raise ValueError('invalid mount target')
        rows.append((target, fields[cut+1], fields[5].split(',')))
    if not rows or not any(row[0] == '/' for row in rows):
        raise ValueError('missing root mount')
    return rows


def share_rows(text):
    lines = text.splitlines()
    if not lines or lines[0] != 'name\tserver\texport\tmode':
        raise ValueError('invalid share header')
    rows = []
    seen = set()
    for line in lines[1:]:
        fields = line.split('\t')
        if len(fields) != 4:
            raise ValueError('invalid share row')
        name, server, export, mode = fields
        if (not re.fullmatch(r'[a-z0-9][a-z0-9_-]{0,62}', name) or name in seen or
                len(server) > 253 or '.' not in server or not all(re.fullmatch(r'[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?', p) for p in server.split('.')) or
                not export.startswith('/') or len(export) > 1024 or not all(re.fullmatch(r'[A-Za-z0-9_.-]+', p) and p not in ('.','..') for p in export[1:].split('/')) or
                mode not in ('manual', 'on-demand')):
            raise ValueError('invalid or duplicate share specification')
        seen.add(name)
        rows.append((name, server, export, mode))
    if not rows:
        raise ValueError('empty share list')
    return rows


def overlap(a, b):
    if b == '/':
        return False
    b = os.path.normpath(b)
    return a == b or a.startswith(b.rstrip('/') + '/') or b.startswith(a + '/')


def candidate(row):
    name, server, export, mode = row
    opts = 'ro,nosuid,nodev,noexec,hard,_netdev,vers=4'
    if mode == 'manual':
        opts += ',noauto'
    else:
        opts += ',nofail,x-systemd.automount,x-systemd.idle-timeout=300s,x-systemd.mount-timeout=15s'
    return server + ':' + export + '\t/mnt/sasd/' + name + '\tnfs\t' + opts + '\t0\t0'


def planner():
    sys.dont_write_bytecode = True
    spec = importlib.util.spec_from_file_location('packages', HERE / 'plan-packages.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main():
    p = argparse.ArgumentParser(description=__doc__, allow_abbrev=False)
    mode = p.add_mutually_exclusive_group(required=True)
    mode.add_argument('--live', action='store_true')
    mode.add_argument('--fstab')
    p.add_argument('--mountinfo')
    p.add_argument('--shares')
    for key in ('hostname', 'inventory', 'roles'):
        p.add_argument('--' + key, required=True)
    a = p.parse_args()
    if a.live and (os.geteuid() == 0 or a.mountinfo is not None):
        p.error('live observation requires an ordinary user and no capture override')
    try:
        module = planner()
        profile, stages, context = module.inventory_selection(a.hostname, a.inventory, a.roles)
        fstab = fstab_rows(read_text('/etc/fstab' if a.live else a.fstab))
        mounts = mount_rows(read_text('/proc/self/mountinfo' if a.live else a.mountinfo, a.live)) if a.live or a.mountinfo else None
        shares = share_rows(read_text(a.shares)) if a.shares else []
    except (OSError, ValueError, subprocess.SubprocessError) as exc:
        print('plan-storage: ' + str(exc), file=sys.stderr)
        return 2
    print('SASD-STORAGE-PLAN-1\nscope\t' + ('LOCAL_READ_ONLY' if a.live else 'CAPTURE_ONLY'))
    print('profile\t' + profile + '\ninventory-host\t' + a.hostname)
    print('inventory-plan-sha256\t' + context['client-plan'])
    print('runtime-identity\tNOT_VERIFIED')
    print('fstab-rows\t' + str(len(fstab)))
    for target, required in (('/home', {'nodev','nosuid','noexec'}), ('/tmp', {'nodev','nosuid','noexec'}), ('/var', {'nodev','nosuid'}), ('/dev/shm', {'nodev','nosuid','noexec'})):
        found = [opts for path, _, opts in fstab if path == target]
        status = 'NOT_EXPLICIT' if not found else 'OPTIONS_PRESENT' if len(found) == 1 and required <= set(found[0]) and not set(found[0]) & {'dev','suid','exec'} else 'REVIEW_REQUIRED'
        print('fstab-policy\t' + target + '\t' + status)
    if mounts is None:
        print('mountinfo\tNOT_RUN')
    else:
        print('mount-count\t' + str(len(mounts)))
        print('nfs-mount-count\t' + str(sum(t in ('nfs','nfs4') for _, t, _ in mounts)))
    selected = any('nfs-common' in names for names in stages.values())
    print('nfs-package\t' + ('SELECTED' if selected else 'NOT_SELECTED'))
    print('share-input\t' + ('REVIEW_REQUIRED' if shares else 'INPUT_REQUIRED'))
    for row in shares:
        target = '/mnt/sasd/' + row[0]
        conflict = any(overlap(target, path) for path, _, _ in fstab + (mounts or []))
        status = 'CONFLICT' if conflict else 'PACKAGE_NOT_SELECTED' if not selected else 'MOUNT_STATE_UNKNOWN' if mounts is None else 'REVIEW_REQUIRED'
        print('share\t' + row[0] + '\t' + status)
        if status == 'REVIEW_REQUIRED':
            print('fstab-candidate\t' + candidate(row))
    if a.live:
        try:
            os_info = platform.freedesktop_os_release()
            os_version = os_info.get('ID', 'unknown') + ':' + os_info.get('VERSION_ID', 'unknown')
        except OSError:
            os_version = 'UNKNOWN'
        try:
            mem = re.search(r'^MemTotal:\s+(\d+) kB$', read_text('/proc/meminfo', True), re.M)
            memory = mem[1] if mem else 'UNKNOWN'
        except (OSError, ValueError):
            memory = 'UNKNOWN'
        for label, value in (('os', os_version), ('kernel', platform.release()), ('architecture', platform.machine()), ('logical-cpus', str(os.cpu_count() or 0)), ('memory-kib', memory)):
            print('inventory\t' + label + '\t' + (value if re.fullmatch(r'[A-Za-z0-9_.+:~-]+', value) else 'UNKNOWN'))
    print('mountpoint-directory-state\tNOT_CHECKED')
    print('usb-automount\tREVIEW_DESKTOP_POLICY')
    print('storage-apply\tNOT_AUTHORIZED')
    return 3


if __name__ == '__main__':
    sys.exit(main())
