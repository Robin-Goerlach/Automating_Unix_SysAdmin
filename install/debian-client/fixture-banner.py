#!/usr/bin/python3 -I
"""Reference-bound two-file login banner transaction, exclusively in a private fixture."""
import argparse
import fcntl
import importlib.util
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys

HERE = Path(__file__).resolve().parent
NAMES = ('issue', 'issue.net')
FORMAT = 'SASD-BANNER-FIXTURE-1'


def load(name):
    sys.dont_write_bytecode = True
    spec = importlib.util.spec_from_file_location(name, HERE / (name + '.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def transaction():
    # A fresh module instance scoped exclusively to these two fixture files.
    # No changes to the native installer's default baseline target set.
    module = load('native-install')
    module.NAMES = NAMES
    return module


def directory(path, owner):
    info = path.lstat()
    if (not stat.S_ISDIR(info.st_mode) or info.st_uid != owner or info.st_gid != owner or
            stat.S_IMODE(info.st_mode) != 0o700 or os.listxattr(path, follow_symlinks=False)):
        raise ValueError('unsafe fixture directory')
    return [info.st_dev, info.st_ino, info.st_uid, info.st_gid]


def fixture(root, owner, tx):
    if (owner == 0 or os.getuid() != owner or os.getegid() != owner or
            not re.fullmatch(r'/tmp/sasd-banner-lab\.[A-Za-z0-9_]+', str(root)) or root.resolve() != root):
        raise ValueError('ordinary-user private banner fixture required')
    paths = (root, root / 'etc', root / 'transactions')
    identities = [directory(path, owner) for path in paths]
    if len({identity[0] for identity in identities}) != 1:
        raise ValueError('fixture must use one filesystem')
    marker, mode = tx.read_file(root / '.sasd-banner-fixture', owner, 128, target=True)
    if marker != (FORMAT + '\n').encode('ascii') or mode != 0o600:
        raise ValueError('invalid fixture marker')
    return identities


def reference(path, owner, tx):
    data, mode = tx.read_file(path, owner, 65536, target=True)
    if mode != 0o600:
        raise ValueError('reference must be private')
    value = json.loads(data, object_pairs_hook=tx.unique_pairs)
    if not isinstance(value, dict):
        raise ValueError('invalid reference')
    return value


def render(host, tx):
    result = tx.command('/bin/sh', str(HERE / 'tasks/0460_Login_Banner'), '--hostname=' + host, '--render')
    if result != b'Unauthorized access is prohibited.\n':
        raise ValueError('unexpected banner renderer output')
    return result


def main():
    p = argparse.ArgumentParser(description=__doc__, allow_abbrev=False)
    modes = p.add_mutually_exclusive_group(required=True)
    modes.add_argument('--review', action='store_true')
    modes.add_argument('--apply-fixture', action='store_true')
    modes.add_argument('--verify', action='store_true')
    modes.add_argument('--recover')
    for key in ('root', 'hostname', 'inventory', 'roles'):
        p.add_argument('--' + key, required=True)
    p.add_argument('--reference')
    a = p.parse_args()
    if bool(a.reference) == a.review:
        p.error('only review omits the reference')
    if a.recover is not None and not re.fullmatch(r'native\.[0-9a-f]{32}\.json', a.recover):
        p.error('invalid journal name')
    owner = os.geteuid()
    os.umask(0o077)
    try:
        tx = transaction()
        root = Path(a.root)
        identities = fixture(root, owner, tx)
        etc, store = root / 'etc', root / 'transactions'
        fd = os.open(store, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            if fixture(root, owner, tx) != identities or [os.fstat(fd).st_dev, os.fstat(fd).st_ino] != identities[2][:2]:
                raise ValueError('fixture identity changed')
            pkg = load('plan-packages')
            _, _, context = pkg.inventory_selection(a.hostname, a.inventory, a.roles)
            release = load('lab-install').release_digest()
            common = {'format': FORMAT, 'root': str(root), 'directories': identities,
                      'host': a.hostname, 'inventory': context, 'release': release}
            original = tx.snapshot(etc, owner)
            # Existing regular 0644 files only; no creation, hardlinks or mode repair.
            if any(entry['mode'] != 0o644 for entry in original.values()):
                raise ValueError('fixture banner files must already have mode 0644')
            content = render(a.hostname, tx)
            desired = {name: {'data': content.hex(), 'mode': 0o644} for name in NAMES}
            current = dict(common, original=tx.digest(tx.encoded(original)),
                           desired=tx.digest(tx.encoded(desired)))
            if a.recover is None and tx.pending(store, owner):
                raise ValueError('open journal requires explicit recovery')
            if a.review:
                sys.stdout.buffer.write(tx.encoded(current))
                return 0
            approved = reference(Path(a.reference), owner, tx)
            if (set(approved) != set(current) or
                    any(approved[key] != current[key] for key in current if key != 'original') or
                    not isinstance(approved['original'], str) or
                    not re.fullmatch(r'[0-9a-f]{64}', approved['original'])):
                raise ValueError('reference context mismatch')
            if a.verify:
                print('STATIC_BANNER_MATCH' if original == desired else 'STATIC_BANNER_DRIFT')
                print('native-apply\tNOT_AUTHORIZED')
                return 0 if original == desired else 1
            # Persist the existing private fixture layout before starting a transaction.
            for directory_path in (etc, store, root, Path('/tmp')):
                tx.sync_dir(directory_path)
            if fixture(root, owner, tx) != identities or load('lab-install').release_digest() != release:
                raise ValueError('fixture or release changed')
            if a.apply_fixture:
                if approved != current:
                    raise ValueError('original snapshot differs from reviewed reference')
                path = tx.transition(etc, store, owner, approved, original, desired,
                                     lambda: tx.snapshot(etc, owner) == desired)
                print('COMMITTED_BANNER_FIXTURE\t' + path.name)
            else:
                tx.recover(etc, store, owner, approved, store / a.recover)
                print('ROLLED_BACK_BANNER_FIXTURE\t' + a.recover)
            print('native-apply\tNOT_AUTHORIZED')
            return 0
        finally:
            os.close(fd)
    except (OSError, ValueError, subprocess.SubprocessError, RuntimeError):
        print('fixture-banner: invalid input, conflict or incomplete transaction; inspect private journal', file=sys.stderr)
        return 2


if __name__ == '__main__':
    sys.exit(main())
