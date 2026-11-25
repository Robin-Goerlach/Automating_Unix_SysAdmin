#!/usr/bin/python3 -I
"""Review local account and security policy metadata without changing authentication."""
import argparse
import importlib.util
from pathlib import Path
import os
import re
import stat
import subprocess
import sys

HERE = Path(__file__).resolve().parent
NAME = re.compile(r'[A-Za-z_][A-Za-z0-9_.-]*\$?')
LIMIT = 1024 * 1024
PATHS = ('/etc/passwd', '/etc/group', '/etc/shadow', '/etc/gshadow',
         '/etc/login.defs', '/etc/pam.d/common-auth', '/etc/pam.d/common-password',
         '/etc/pam.d/common-session', '/etc/security/limits.conf', '/etc/security/limits.d',
         '/etc/sudoers', '/etc/sudoers.d', '/etc/cron.allow', '/etc/cron.deny',
         '/etc/at.allow', '/etc/at.deny')


def load(name):
    sys.dont_write_bytecode = True
    spec = importlib.util.spec_from_file_location(name, HERE / (name + '.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def read_input(path):
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    with os.fdopen(fd, 'rb') as stream:
        info = os.fstat(fd)
        if not stat.S_ISREG(info.st_mode) or info.st_size > LIMIT:
            raise ValueError('unsafe or oversized input')
        data = stream.read(LIMIT + 1)
        after = os.fstat(fd)
        if len(data) != info.st_size or (info.st_mtime_ns, info.st_ctime_ns) != (after.st_mtime_ns, after.st_ctime_ns):
            raise ValueError('input changed while reading')
        if any(c < 32 and c not in (9, 10) or c == 127 for c in data):
            raise ValueError('invalid input bytes')
        return data.decode('utf-8')


def number(value):
    if not re.fullmatch(r'[0-9]{1,10}', value) or int(value) >= 4294967295:
        raise ValueError('invalid numeric identity')
    return int(value)


def accounts(text):
    rows = []
    for line in text.splitlines():
        parts = line.split(':')
        if len(parts) != 7 or not NAME.fullmatch(parts[0]):
            raise ValueError('invalid passwd record')
        name, password, uid, gid, _, home, shell = parts
        rows.append((name, number(uid), number(gid), password in ('x', '*', '!', '!!'),
                     home.startswith('/') and '..' not in home.split('/'),
                     not shell or shell.startswith('/')))
    if not rows:
        raise ValueError('empty passwd input')
    return rows


def groups(text):
    rows = []
    for line in text.splitlines():
        parts = line.split(':')
        if len(parts) != 4 or not NAME.fullmatch(parts[0]):
            raise ValueError('invalid group record')
        name, _, gid, members = parts
        members = members.split(',') if members else []
        if any(not NAME.fullmatch(v) for v in members) or len(members) != len(set(members)):
            raise ValueError('invalid group membership')
        rows.append((name, number(gid), members))
    if not rows:
        raise ValueError('empty group input')
    return rows


def summarize(users, group_rows):
    names = {r[0] for r in users}
    gids = {r[1] for r in group_rows}
    return {
        'accounts': len(users), 'groups': len(group_rows),
        'duplicate-user-names': len(users) - len(names),
        'duplicate-uids': len(users) - len({r[1] for r in users}),
        'unexpected-uid-zero': sum(r[1] == 0 and r[0] != 'root' for r in users),
        'root-uid-zero-count': sum(r[0] == 'root' and r[1] == 0 for r in users),
        'passwd-field-review': sum(not r[3] for r in users),
        'home-path-review': sum(not r[4] for r in users),
        'shell-path-review': sum(not r[5] for r in users),
        'duplicate-group-names': len(group_rows) - len({r[0] for r in group_rows}),
        'duplicate-gids': len(group_rows) - len(gids),
        'primary-gid-not-local': sum(r[2] not in gids for r in users),
        'group-member-not-local': sum(v not in names for r in group_rows for v in r[2]),
        'video-memberships': sum(len(set(r[2]) | {u[0] for u in users if u[2] == r[1]}) for r in group_rows if r[0] == 'video'),
        'sudo-memberships': sum(len(set(r[2]) | {u[0] for u in users if u[2] == r[1]}) for r in group_rows if r[0] == 'sudo'),
    }


def hash_policy(text):
    values = [line.split()[1:] for line in text.splitlines()
              if line.split()[:1] == ['ENCRYPT_METHOD']]
    if not values:
        return 'NOT_EXPLICIT'
    if len(values) != 1 or len(values[0]) != 1:
        return 'REVIEW_REQUIRED'
    return values[0][0] if values[0][0] in ('YESCRYPT', 'SHA512', 'SHA256', 'MD5', 'DES') else 'REVIEW_REQUIRED'


def sensitive_mode(root, path, observer, owner=0):
    expected = {'/etc/shadow': {0o600, 0o640}, '/etc/gshadow': {0o600, 0o640},
                '/etc/sudoers': {0o440}, '/etc/sudoers.d': {0o700, 0o750, 0o755}}
    state = observer(root, path, owner)
    kind = 'DIRECTORY_OBSERVED' if path == '/etc/sudoers.d' else 'FILE_OBSERVED'
    if state != kind:
        return state if state not in ('FILE_OBSERVED', 'DIRECTORY_OBSERVED') else 'TYPE_REVIEW'
    try:
        info = (root / path.lstrip('/')).lstat()
        if info.st_uid != owner or stat.S_IMODE(info.st_mode) not in expected[path]:
            return 'MODE_REVIEW'
        if path in ('/etc/sudoers', '/etc/sudoers.d') and info.st_gid != owner:
            return 'GROUP_REVIEW'
        return 'MODE_MATCH_ONLY'
    except OSError:
        return 'UNKNOWN'


def main():
    p = argparse.ArgumentParser(description=__doc__, allow_abbrev=False)
    mode = p.add_mutually_exclusive_group(required=True)
    mode.add_argument('--live', action='store_true')
    mode.add_argument('--capture')
    for key in ('hostname', 'inventory', 'roles'):
        p.add_argument('--' + key, required=True)
    a = p.parse_args()
    if a.live and os.geteuid() == 0:
        p.error('live observation requires an ordinary user')
    try:
        profile, _, context = load('plan-packages').inventory_selection(a.hostname, a.inventory, a.roles)
        source = Path('/etc' if a.live else a.capture)
        if not source.is_dir() or source.is_symlink():
            raise ValueError('invalid capture directory')
        summary = summarize(accounts(read_input(source / 'passwd')), groups(read_input(source / 'group')))
        method = hash_policy(read_input(source / 'login.defs'))
    except (OSError, ValueError, subprocess.SubprocessError):
        print('plan-security: invalid or unavailable input', file=sys.stderr)
        return 2
    print('SASD-SECURITY-PLAN-1\nscope\t' + ('LOCAL_READ_ONLY' if a.live else 'CAPTURE_ONLY'))
    print('profile\t' + profile + '\ninventory-host\t' + a.hostname)
    print('inventory-plan-sha256\t' + context['client-plan'])
    for key, value in summary.items():
        print('account-summary\t' + key + '\t' + str(value))
    print('login-defs-method\t' + method)
    if a.live:
        observer = load('plan-shell').observe
        for path in PATHS:
            print('metadata\t' + path + '\t' + observer(Path('/'), path))
        for path in ('/etc/shadow', '/etc/gshadow', '/etc/sudoers', '/etc/sudoers.d'):
            print('sensitive-mode\t' + path + '\t' + sensitive_mode(Path('/'), path, observer))
    print('shadow-content\tNOT_READ\n' + 'effective-pam-sudo-nss\tNOT_VERIFIED')
    print('runtime-identity\tNOT_VERIFIED\nsecurity-apply\tNOT_AUTHORIZED')
    return 3


if __name__ == '__main__':
    sys.exit(main())
