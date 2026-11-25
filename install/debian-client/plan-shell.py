#!/usr/bin/python3 -I
"""Review fixed startup and compatibility paths without reading or sourcing profiles."""
import argparse
import importlib.util
import os
from pathlib import Path
import stat
import subprocess
import sys

HERE = Path(__file__).resolve().parent
PATHS = ('/root', '/root/bin', '/root/Documents', '/root/tmp', '/root/mnt',
         '/root/.profile', '/root/.bashrc', '/root/.cshrc', '/root/.login',
         '/root/.exrc', '/root/.vimrc', '/root/.curlrc', '/root/.ssh/authorized_keys',
         '/etc/profile', '/etc/profile.d', '/etc/bash.bashrc', '/etc/csh.cshrc',
         '/etc/csh.cshrc.local', '/etc/cshrc', '/srv', '/var/log/messages',
         '/etc/sysconfig', '/etc/HOSTNAME', '/etc/openssh', '/var/home', '/usr/man',
         '/usr/share/man', '/usr/bin/more', '/usr/bin/less', '/usr/bin/man',
         '/usr/bin/csh', '/usr/bin/tcsh')


def observe(root, path, owner=0):
    """Metadata only, reject symbolic ancestors; assumes stable trusted tree."""
    current = root
    try:
        for i, part in enumerate(Path(path).parts[1:]):
            current = current / part
            info = current.lstat()
            if stat.S_ISLNK(info.st_mode):
                return 'SYMLINK_REVIEW'
            if i < len(Path(path).parts) - 2 and not stat.S_ISDIR(info.st_mode):
                return 'TYPE_REVIEW'
            if info.st_uid != owner or stat.S_IMODE(info.st_mode) & 0o7022:
                return 'METADATA_REVIEW'
        if stat.S_ISDIR(info.st_mode):
            return 'DIRECTORY_OBSERVED'
        if stat.S_ISREG(info.st_mode):
            return 'FILE_OBSERVED' if info.st_nlink == 1 else 'HARDLINK_REVIEW'
        return 'TYPE_REVIEW'
    except FileNotFoundError:
        return 'MISSING'
    except OSError:
        return 'UNKNOWN'


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
        sys.dont_write_bytecode = True
        spec = importlib.util.spec_from_file_location('packages', HERE / 'plan-packages.py')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        profile, _, context = module.inventory_selection(a.hostname, a.inventory, a.roles)
    except (OSError, ValueError, subprocess.SubprocessError) as exc:
        print('plan-shell: ' + str(exc), file=sys.stderr)
        return 2
    print('SASD-SHELL-PLAN-1\nscope\t' + ('LOCAL_METADATA_ONLY' if a.live else 'POLICY_ONLY'))
    print('profile\t' + profile + '\ninventory-host\t' + a.hostname)
    print('inventory-plan-sha256\t' + context['client-plan'])
    print('path\tstatus')
    for path in PATHS:
        print(path + '\t' + (observe(Path('/'), path) if a.live else 'REVIEW_REQUIRED'))
    print('startup-content\tNOT_READ')
    print('runtime-identity\tNOT_VERIFIED')
    print('shell-apply\tNOT_AUTHORIZED')
    return 3 if a.live else 0


if __name__ == '__main__':
    sys.exit(main())
