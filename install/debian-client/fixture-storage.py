#!/usr/bin/python3 -I
"""Review and update a private fstab fixture; never mount or modify AutoFS."""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import posixpath
import re
import sys

HERE = Path(__file__).resolve().parent
FORMAT = 'SASD-STORAGE-FIXTURE-1'
PREFIX = 'sasd-storage-lab'
MARKER = '.sasd-storage-fixture'
LABEL = 'STORAGE'
DIRECTORIES = ()
PROFILES = ('baseline', 'workstation', 'laptop', 'server')
NAMES = ('fstab',)
HARDEN = {'/home': ('nodev', 'nosuid', 'noexec'),
          '/tmp': ('nodev', 'nosuid', 'noexec'),
          '/var': ('nodev', 'nosuid'),
          '/dev/shm': ('nodev', 'nosuid', 'noexec')}
LOCAL_TYPES = {'ext4', 'xfs', 'btrfs', 'tmpfs'}
# Intentionally small reviewed subset, not a general filesystem option grammar.
LOCAL_OPTIONS = {'defaults', 'ro', 'rw', 'nodev', 'nosuid', 'noexec',
                 'noatime', 'relatime', 'strictatime', 'nodiratime', 'diratime',
                 'lazytime', 'nolazytime', 'sync', 'async', 'discard', 'nodiscard',
                 'errors=remount-ro', 'errors=continue', 'errors=panic'}
CONFLICTS = ({'ro', 'rw'}, {'noatime', 'relatime', 'strictatime'},
             {'nodiratime', 'diratime'}, {'lazytime', 'nolazytime'},
             {'sync', 'async'}, {'discard', 'nodiscard'},
             {'errors=remount-ro', 'errors=continue', 'errors=panic'})

sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('fixture_config', HERE / 'fixture-config.py')
engine = importlib.util.module_from_spec(spec)
spec.loader.exec_module(engine)


def checked_text(value):
    if not isinstance(value, str) or len(value) > 65536:
        raise ValueError('invalid capture')
    data = value.encode('ascii')
    if any(c < 32 and c not in (9, 10) or c == 127 for c in data):
        raise ValueError('invalid capture bytes')
    return value


def path_key(path):
    if not path.startswith('/') or path.startswith('//') or posixpath.normpath(path) != path:
        raise ValueError('noncanonical mount target')
    if any(ord(c) < 32 or ord(c) == 127 for c in path):
        raise ValueError('unsupported target control character')
    return path


def model(request, stages, planner):
    """Preserve original lines; append only explicit reviewed safe candidates.

    Captures are synthetic and must be complete for this model. No runtime
    observation, filesystem probing, native mount parsing or authorization.
    """
    fields = {'fstab', 'mountinfo', 'autofs_targets', 'harden', 'shares'}
    if not isinstance(request, dict) or set(request) != fields:
        raise ValueError('invalid storage request fields')
    original = checked_text(request['fstab'])
    if original and not original.endswith('\n'):
        raise ValueError('fstab requires final newline')
    rows = planner.fstab_rows(original)
    mounts = planner.mount_rows(checked_text(request['mountinfo']))
    targets = [path_key(t) for t, _, _ in rows if t.startswith('/')]
    if len(set(targets)) != len(targets):
        raise ValueError('duplicate fstab mount target')
    if targets.count('/') != 1:
        raise ValueError('explicit root fstab row required')
    for target, _, _ in mounts:
        path_key(target)
    automount = request['autofs_targets']
    if (not isinstance(automount, list) or len(automount) > 128 or
            any(not isinstance(t, str) or len(t) > 1024 or t == '/' for t in automount)):
        raise ValueError('invalid AutoFS target capture')
    if len(set(automount)) != len(automount):
        raise ValueError('duplicate AutoFS target')
    for target in automount:
        path_key(target)
    harden = request['harden']
    if (not isinstance(harden, list) or
            any(not isinstance(t, str) or t not in HARDEN for t in harden) or
            len(set(harden)) != len(harden)):
        raise ValueError('invalid hardening selection')
    if not set(harden) <= set(targets):
        raise ValueError('cannot invent separate local filesystem')
    # Keep every byte outside the options field of the explicitly selected rows.
    output = []
    for line in original.splitlines(keepends=True):
        if not line.strip() or line.lstrip().startswith('#'):
            output.append(line)
            continue
        columns = list(re.finditer(r'\S+', line))
        target = planner.unescape(columns[1].group())
        if target not in harden:
            output.append(line)
            continue
        fstype = columns[2].group()
        opts = columns[3].group().split(',')
        required = HARDEN[target]
        if (fstype not in LOCAL_TYPES or len(set(opts)) != len(opts) or
                not set(opts) <= LOCAL_OPTIONS or
                any(len(set(opts) & group) > 1 for group in CONFLICTS) or
                (fstype != 'ext4' and any(o.startswith('errors=') for o in opts))):
            raise ValueError('local options require manual review')
        if any(planner.overlap(target, t) for t in automount):
            raise ValueError('local mount overlaps AutoFS')
        new = opts + [o for o in required if o not in opts]
        start, end = columns[3].span()
        output.append(line[:start] + ','.join(new) + line[end:])
    share_text = checked_text(request['shares'])
    shares = planner.share_rows(share_text) if share_text else []
    if shares and not any('nfs-common' in names for names in stages.values()):
        raise ValueError('NFS not selected by package profile')
    for row in shares:
        target = '/mnt/sasd/' + row[0]
        candidate = planner.candidate(row)
        # Exact previously rendered line is reusable, never replace another entry.
        existing = [t for t in targets if planner.overlap(target, t)]
        if any(planner.overlap(target, t) for t, _, _ in mounts) or any(
                planner.overlap(target, t) for t in automount):
            raise ValueError('NFS overlaps observed mount or AutoFS target')
        if existing:
            if existing != [target] or candidate + '\n' not in output:
                raise ValueError('NFS conflicts with existing fstab')
        else:
            output.append(candidate + '\n')
            targets.append(target)
    result = ''.join(output)
    planner.fstab_rows(result)
    if len(result.encode('ascii')) > 65536:
        raise ValueError('desired fstab exceeds fixture limit')
    return result.encode('ascii')


def prepare(root, host, profile, stages, tx):
    data, mode = tx.read_file(root / 'request.json', os.geteuid(), 65536, target=True)
    if mode != 0o600:
        raise ValueError('storage request must be private')
    request = json.loads(data, object_pairs_hook=tx.unique_pairs)
    result = model(request, stages, engine.load('plan-storage'))
    original = {'fstab': {'data': request['fstab'].encode('ascii').hex(), 'mode': 0o644}}
    binding = {'request-sha256': hashlib.sha256(data).hexdigest(),
               'harden-count': len(request['harden'])}
    return binding, original, {'fstab': result}


if __name__ == '__main__':
    sys.exit(engine.run(sys.modules[__name__]))
