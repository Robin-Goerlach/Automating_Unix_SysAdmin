#!/usr/bin/python3 -I
"""Read-only security tool review and offline candidate integrity comparison."""
import argparse
import hashlib
import importlib.util
import os
from pathlib import Path
import re
import stat
import subprocess
import sys

HERE = Path(__file__).resolve().parent
PACKAGES = ('aide', 'rkhunter', 'clamav', 'clamav-freshclam', 'clamav-daemon', 'lynis', 'auditd', 'chkrootkit')
PATHS = ('/etc/aide', '/var/lib/aide', '/etc/rkhunter.conf', '/etc/clamav',
         '/etc/lynis', '/etc/audit/rules.d', '/etc/cron.daily/aide',
         '/etc/cron.daily/rkhunter', '/etc/cron.daily/chkrootkit', '/etc/cron.d/aide')
NAMES = ('hostname', 'hosts', 'rsyslog.conf', 'logrotate.conf')
HEADER = 'SASD-AUDIT-BASELINE-1'


def load(name):
    sys.dont_write_bytecode = True
    spec = importlib.util.spec_from_file_location(name, HERE / (name + '.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def private_read(path):
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    with os.fdopen(fd, 'rb') as stream:
        info = os.fstat(fd)
        mode = stat.S_IMODE(info.st_mode)
        if (not stat.S_ISREG(info.st_mode) or info.st_uid != os.geteuid() or
                info.st_nlink != 1 or mode & 0o7022 or info.st_size > 65536):
            raise ValueError('unsafe snapshot file')
        data = stream.read(65537)
        after = os.fstat(fd)
        if len(data) != info.st_size or (info.st_mtime_ns, info.st_ctime_ns) != (after.st_mtime_ns, after.st_ctime_ns):
            raise ValueError('snapshot file changed')
        return data, mode


def snapshot(root, host, plan):
    root = Path(root)
    if (not root.is_absolute() or root == Path('/') or root.resolve() != root or
            not root.is_dir() or root.stat().st_uid != os.geteuid() or stat.S_IMODE(root.stat().st_mode) != 0o700):
        raise ValueError('snapshot requires an owned private canonical directory')
    rows = [HEADER, 'host\t' + host, 'inventory-plan\t' + plan, 'file\tmode\tsha256']
    for name in NAMES:
        data, mode = private_read(root / name)
        rows.append('%s\t%03o\t%s' % (name, mode, hashlib.sha256(data).hexdigest()))
    return '\n'.join(rows) + '\n'


def compare(reference, current):
    expected = reference.splitlines()
    actual = current.splitlines()
    if len(expected) != 4 + len(NAMES) or expected[:4] != actual[:4] or reference != '\n'.join(expected) + '\n':
        raise ValueError('invalid reference or inventory context mismatch')
    result = []
    for name, old, new in zip(NAMES, expected[4:], actual[4:]):
        if not re.fullmatch(re.escape(name) + r'\t[0-7]{3}\t[0-9a-f]{64}', old):
            raise ValueError('invalid reference row')
        result.append((name, 'MATCH' if old == new else 'DRIFT'))
    return result


def package_state(module, package):
    try:
        result = module.command('/usr/bin/dpkg-query', '-W', '-f=${db:Status-Abbrev}\\t${Version}\\n', package)
        if result.returncode == 0 and not result.stderr.strip():
            return module.installed_result(result.stdout)[0]
    except (OSError, ValueError, subprocess.SubprocessError):
        pass
    return 'UNKNOWN'


def main():
    p = argparse.ArgumentParser(description=__doc__, allow_abbrev=False)
    mode = p.add_mutually_exclusive_group(required=True)
    mode.add_argument('--live', action='store_true')
    mode.add_argument('--list', action='store_true')
    mode.add_argument('--snapshot')
    p.add_argument('--reference')
    for key in ('hostname', 'inventory', 'roles'):
        p.add_argument('--' + key, required=True)
    a = p.parse_args()
    if os.geteuid() == 0 or (a.reference is not None and a.snapshot is None):
        p.error('ordinary user required; reference requires snapshot')
    try:
        module = load('plan-packages')
        profile, stages, context = module.inventory_selection(a.hostname, a.inventory, a.roles)
        if a.snapshot is not None:
            current = snapshot(a.snapshot, a.hostname, context['client-plan'])
            if a.reference is None:
                sys.stdout.write(current)
                return 0
            old, _ = private_read(Path(a.reference))
            rows = compare(old.decode('ascii'), current)
            print('SASD-AUDIT-COMPARE-1')
            for name, status in rows:
                print(name + '\t' + status)
            print('integrity-apply\tNOT_AUTHORIZED')
            return 1 if any(status == 'DRIFT' for _, status in rows) else 0
        selected = {n for names in stages.values() for n in names}
        print('SASD-AUDIT-PLAN-1\nscope\t' + ('LOCAL_READ_ONLY' if a.live else 'POLICY_ONLY'))
        print('profile\t' + profile + '\ninventory-host\t' + a.hostname)
        print('inventory-plan-sha256\t' + context['client-plan'])
        for package in PACKAGES:
            print('\t'.join(('package', package, 'SELECTED' if package in selected else 'NOT_SELECTED', package_state(module, package) if a.live else 'NOT_RUN')))
        observer = load('plan-shell').observe if a.live else None
        for path in PATHS:
            print('metadata\t' + path + '\t' + (observer(Path('/'), path) if observer else 'NOT_RUN'))
        print('schedule-coverage\tNOT_VERIFIED\nscanner-execution\tNOT_RUN\naide-baseline\tNOT_APPROVED')
        print('runtime-identity\tNOT_VERIFIED\naudit-apply\tNOT_AUTHORIZED')
        return 3 if a.live else 0
    except (OSError, ValueError, subprocess.SubprocessError, RuntimeError):
        print('plan-audits: invalid or unavailable input', file=sys.stderr)
        return 2


if __name__ == '__main__':
    sys.exit(main())
