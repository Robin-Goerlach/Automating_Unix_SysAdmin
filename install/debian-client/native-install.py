#!/usr/bin/python3 -I
"""Experimental native static baseline installer for an explicitly approved lab VM."""
import argparse
import fcntl
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys
import tempfile
import uuid

HERE = Path(__file__).absolute().parent
NAMES = ('hostname', 'hosts', 'resolv.conf')
ENV = {'PATH': '/usr/sbin:/usr/bin:/sbin:/bin', 'LC_ALL': 'C'}
STATES = ('APPLYING', 'ROLLING_BACK', 'COMMITTED_STATIC', 'ROLLED_BACK')
JOURNAL_LIMIT = 1024 * 1024


def require(ok, reason):
    if not ok:
        raise ValueError(reason)


def encoded(value):
    return (json.dumps(value, sort_keys=True, separators=(',', ':')) + '\n').encode('ascii')


def digest(data):
    return hashlib.sha256(data).hexdigest()


def unique_pairs(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, 'duplicate JSON key')
        result[key] = value
    return result


def read_file(path, owner, limit, target=False):
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    with os.fdopen(fd, 'rb') as stream:
        info = os.fstat(fd)
        mode = stat.S_IMODE(info.st_mode)
        require(stat.S_ISREG(info.st_mode) and info.st_uid == owner and info.st_nlink == 1
                and not mode & 0o7022 and info.st_size <= limit, 'unsafe file metadata')
        if target:
            require(info.st_gid == owner and not os.listxattr(fd), 'unsupported target metadata')
        data = stream.read(limit + 1)
        after = os.fstat(fd)
        require(len(data) == info.st_size and (info.st_mtime_ns, info.st_ctime_ns) ==
                (after.st_mtime_ns, after.st_ctime_ns), 'file changed while reading')
        return data, mode


def snapshot(etc, owner):
    result = {}
    for name in NAMES:
        data, mode = read_file(etc / name, owner, 65536, target=True)
        require(b'\0' not in data, 'binary target not supported')
        result[name] = {'data': data.hex(), 'mode': mode}
    return result


def validate_snapshot(value):
    require(isinstance(value, dict) and set(value) == set(NAMES), 'invalid snapshot names')
    for entry in value.values():
        require(isinstance(entry, dict) and set(entry) == {'data', 'mode'} and
                type(entry['mode']) is int and 0 <= entry['mode'] <= 0o777 and
                not entry['mode'] & 0o022 and isinstance(entry['data'], str) and
                len(entry['data']) <= 131072 and re.fullmatch(r'(?:[0-9a-f]{2})*', entry['data']),
                'invalid snapshot entry')


def sync_dir(path):
    fd = os.open(path, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def sync_targets(etc, owner, expected):
    """Flush every target, including unchanged files, before terminal journal state."""
    require(snapshot(etc, owner) == expected, 'target changed before synchronization')
    for name in NAMES:
        fd = os.open(etc / name, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
        try:
            info = os.fstat(fd)
            require(stat.S_ISREG(info.st_mode) and info.st_uid == owner and
                    info.st_gid == owner and info.st_nlink == 1, 'unsafe sync target')
            os.fsync(fd)
        finally:
            os.close(fd)
    for parent in sorted({(etc / name).parent for name in NAMES}, key=str):
        if parent != etc:
            sync_dir(parent)
    sync_dir(etc)
    require(snapshot(etc, owner) == expected, 'target changed during synchronization')


def atomic_write(path, data, mode, owner):
    fd, temp = tempfile.mkstemp(prefix='.sasd-write.', dir=path.parent)
    try:
        with os.fdopen(fd, 'wb') as stream:
            info = os.fstat(fd)
            require(info.st_uid == owner and info.st_gid == owner, 'unexpected staging owner/group')
            stream.write(data)
            stream.flush()
            os.fchmod(fd, mode)
            require(not os.listxattr(fd), 'unexpected staging attributes')
            os.fsync(fd)
        os.replace(temp, path)
        sync_dir(path.parent)
    finally:
        if os.path.exists(temp):
            os.unlink(temp)


def journal_write(path, journal, state, owner):
    journal['state'] = state
    data = encoded(journal)
    # Every persisted journal must remain readable by recovery. Reserve room
    # for the longest terminal state before any initial target mutation.
    require(all(len(encoded(dict(journal, state=s))) <= JOURNAL_LIMIT for s in STATES),
            'journal exceeds recovery limit')
    try:
        atomic_write(path, data, 0o600, owner)
    except (OSError, ValueError):
        # Best effort only: a storage failure can prevent persistence of quarantine.
        try:
            atomic_write(path.parent / 'SYNC_FAILED', b'operator review required\n', 0o600, owner)
        except (OSError, ValueError):
            pass
        raise


def load_journal(path, owner):
    data, mode = read_file(path, owner, JOURNAL_LIMIT)
    require(mode == 0o600, 'journal must be private')
    j = json.loads(data, object_pairs_hook=unique_pairs)
    require(isinstance(j, dict) and set(j) == {'format', 'reference', 'original', 'desired', 'state'} and
            j['format'] == 'SASD-NATIVE-JOURNAL-1' and j['state'] in STATES, 'invalid journal')
    validate_snapshot(j['original']); validate_snapshot(j['desired'])
    require(isinstance(j['reference'], dict) and j['reference'].get('original') == digest(encoded(j['original'])) and
            j['reference'].get('desired') == digest(encoded(j['desired'])), 'journal snapshot digest mismatch')
    return j


def pending(store, owner):
    result = []
    for path in store.iterdir():
        require(re.fullmatch(r'native\.[0-9a-f]{32}\.json', path.name), 'unknown journal entry; review required')
        j = load_journal(path, owner)
        if j['state'] in ('APPLYING', 'ROLLING_BACK'):
            result.append(path)
    require(len(result) <= 1, 'ambiguous open journals')
    return result


def transition(etc, store, owner, reference, original, desired, verify, guard=None):
    require(not pending(store, owner), 'open transaction requires recovery')
    validate_snapshot(original); validate_snapshot(desired)
    require(snapshot(etc, owner) == original, 'source changed before apply')
    require(reference['original'] == digest(encoded(original)) and
            reference['desired'] == digest(encoded(desired)), 'reference manifest mismatch')
    path = store / ('native.' + uuid.uuid4().hex + '.json')
    j = {'format': 'SASD-NATIVE-JOURNAL-1', 'reference': reference, 'original': original, 'desired': desired}
    # The durable original and desired snapshots precede any target replacement.
    if guard is not None:
        guard()
    journal_write(path, j, 'APPLYING', owner)
    expected = dict(original)
    for name in NAMES:
        if guard is not None:
            guard()
        current = snapshot(etc, owner)
        require(current == expected, 'target changed during apply')
        if original[name] != desired[name]:
            atomic_write(etc / name, bytes.fromhex(desired[name]['data']), desired[name]['mode'], owner)
        expected[name] = desired[name]
    if guard is not None:
        guard()
    require(snapshot(etc, owner) == desired and verify(), 'static verification failed; recover explicitly')
    sync_targets(etc, owner, desired)
    if guard is not None:
        guard()
    journal_write(path, j, 'COMMITTED_STATIC', owner)
    return path


def recover(etc, store, owner, reference, path, guard=None):
    require(pending(store, owner) == [path], 'requested journal is not the sole open transaction')
    j = load_journal(path, owner)
    require(j['reference'] == reference, 'journal belongs to another reference')
    current = snapshot(etc, owner)
    for name in NAMES:
        require(current[name] in (j['original'][name], j['desired'][name]), 'external target change; recovery refused')
    if guard is not None:
        guard()
    journal_write(path, j, 'ROLLING_BACK', owner)
    expected = dict(current)
    for name in NAMES:
        if guard is not None:
            guard()
        require(snapshot(etc, owner) == expected, 'target changed during rollback')
        if expected[name] != j['original'][name]:
            entry = j['original'][name]
            atomic_write(etc / name, bytes.fromhex(entry['data']), entry['mode'], owner)
            expected[name] = entry
    require(snapshot(etc, owner) == j['original'], 'rollback verification failed')
    sync_targets(etc, owner, j['original'])
    if guard is not None:
        guard()
    journal_write(path, j, 'ROLLED_BACK', owner)


def command(*args):
    r = subprocess.run(args, env=ENV, capture_output=True, timeout=60)
    require(r.returncode == 0, 'required check failed: ' + Path(args[0]).name)
    return r.stdout


def approved_plan(approved, owner, host, expected_state):
    """Validate an independently pinned explicit R2 lifecycle snapshot.

    The operator obtains the digest from the authoritative current site state.
    This is not a live central connection, signature or hostile-writer lock.
    """
    require(re.fullmatch(r'[0-9a-f]{64}', expected_state or ''), 'invalid lifecycle digest')
    names = ('site.conf', 'hosts.tsv', 'roles.tsv', 'host-state.tsv')
    def capture():
        data = {}
        for name in names:
            state = name == 'host-state.tsv'
            raw, mode = read_file(approved / name, owner, 4 * 1024 * 1024, target=state)
            if state:
                require(mode == 0o600, 'private host state snapshot required')
            data[name] = raw
        require(digest(data['host-state.tsv']) == expected_state, 'lifecycle snapshot digest mismatch')
        return data
    data = capture()
    # The canonical Perl planner reads only frozen copies of these validated bytes.
    with tempfile.TemporaryDirectory(prefix='sasd-native-plan.') as tmp:
        root = Path(tmp)
        for name, raw in data.items():
            path = root / name
            path.write_bytes(raw)
            path.chmod(0o600)
        plan = command('/usr/bin/perl', str(HERE / 'plan-client.pl'), '--hostname=' + host,
                       '--inventory=' + str(root / 'hosts.tsv'), '--roles=' + str(root / 'roles.tsv'),
                       '--host-state=' + str(root / 'host-state.tsv'))
    require(capture() == data, 'approved inputs changed during planning')
    return {name: digest(raw) for name, raw in data.items()}, plan


def match_approval(reference, context):
    require(isinstance(reference, dict) and all(reference.get(k) == v for k, v in context.items()),
            'approval context mismatch')


def read_authorization(approved, owner):
    raw, mode = read_file(approved / 'authorization.json', owner, 16384, target=True)
    require(mode == 0o600, 'private authorization required')
    return json.loads(raw, object_pairs_hook=unique_pairs)


def recheck_approval(approved, owner, host, expected_state, hashes, plan, reference):
    """Recheck the entire pinned local context and authorization at write boundaries."""
    require(read_authorization(approved, owner) == reference, 'authorization changed')
    require(approved_plan(approved, owner, host, expected_state) == (hashes, plan),
            'approved context changed during transaction')
    require(read_authorization(approved, owner) == reference, 'authorization changed')


def render(root, host, site, original):
    script = r'''set -eu
root=$1; host=$2; site=$3; here=$4
fail(){ echo "$*" >&2; exit 2; }
. "$here/lib/policy.sh"
. "$here/lib/baseline-render.sh"
valid_hostname || exit 2
expected=$(render_resolver) || exit 2
render_baseline
printf '%s\n\000%s\n\000%s\n\000' "$short" "$hosts" "$resolver"
'''
    values = command('/bin/sh', '-c', script, 'render', str(root), host, str(site), str(HERE)).split(b'\0')
    require(len(values) == 4 and values[-1] == b'', 'invalid rendered output')
    return {n: {'data': data.hex(), 'mode': original[n]['mode']} for n, data in zip(NAMES, values)}


def safe_dir(path, private=False):
    info = path.lstat()
    require(stat.S_ISDIR(info.st_mode) and info.st_uid == 0 and not stat.S_IMODE(info.st_mode) & 0o7022 and
            (not private or stat.S_IMODE(info.st_mode) == 0o700) and not os.listxattr(path, follow_symlinks=False),
            'unsafe root-owned directory')


def release_check(expected):
    require(HERE == Path('/opt/sasd/debian-client'), 'use independently verified root-owned release under /opt/sasd/debian-client')
    for directory in (Path('/'), Path('/opt'), HERE.parent, HERE):
        safe_dir(directory)
    for path in HERE.rglob('*'):
        if path.is_dir():
            safe_dir(path)
        else:
            read_file(path, 0, 4 * 1024 * 1024)
    # The native program must be launched only from the independently verified release.
    sys.dont_write_bytecode = True
    spec = importlib.util.spec_from_file_location('release', HERE / 'lab-install.py')
    module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
    require(module.release_digest() == expected, 'release digest mismatch')


def main():
    p = argparse.ArgumentParser(description=__doc__, allow_abbrev=False)
    modes = p.add_mutually_exclusive_group(required=True)
    modes.add_argument('--review', action='store_true'); modes.add_argument('--apply', action='store_true'); modes.add_argument('--recover')
    p.add_argument('--confirm-disposable-vm', action='store_true', required=True)
    p.add_argument('--confirm-reviewed-gates', action='store_true')
    for key in ('hostname', 'installation', 'fingerprint', 'release', 'host-state-sha256'):
        p.add_argument('--' + key, required=True)
    a = p.parse_args()
    if os.getuid() != 0 or os.geteuid() != 0 or os.getegid() != 0:
        p.error('native operation requires a separately approved root console on the lab VM')
    if a.apply and not a.confirm_reviewed_gates:
        p.error('apply requires operator confirmation of G0-G2 and static resolver ownership')
    os.umask(0o077)
    base = Path('/var/lib/sasd/provisioning'); store = base / 'transactions'; approved = base / 'approved'; etc = Path('/etc')
    try:
        release_check(a.release)
        for directory in (Path('/var'), Path('/var/lib'), base.parent, base, store, approved, etc):
            safe_dir(directory, directory in (store, approved))
        fd = os.open(store, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            command('/usr/bin/python3', '-I', str(HERE / 'native-capabilities.py'), '--live')
            command('/usr/bin/python3', '-I', str(HERE / 'native-identity.py'), '--live', '--hostname=' + a.hostname,
                    '--expected-installation=' + a.installation, '--expected-fingerprint=' + a.fingerprint)
            inputs = {n: approved / n for n in ('site.conf', 'hosts.tsv', 'roles.tsv', 'host-state.tsv')}
            hashes, plan = approved_plan(approved, 0, a.hostname, a.host_state_sha256)
            fields = plan.decode('ascii').splitlines()[1].split('\t')
            require(len(fields) == 7 and fields[:2] == ['host', a.hostname], 'invalid host plan')
            pre = command('/usr/bin/perl', str(HERE / 'native-preflight.pl'), '--live', '--hostname=' + a.hostname,
                          '--address=' + fields[2]).decode('ascii').splitlines()
            require(any(row in pre for row in ('os\tDETECTED\tdebian:12', 'os\tDETECTED\tdebian:13')) and
                    any(row in pre for row in ('virtualization\tDETECTED\tkvm', 'virtualization\tDETECTED\tqemu')),
                    'Debian KVM/QEMU lab required')
            context = {'format': 'SASD-NATIVE-REFERENCE-1', 'scope': 'STATIC_LAB_ONLY', 'hostname': a.hostname,
                       'identity': a.fingerprint, 'release': a.release, 'inputs': hashes, 'plan': digest(plan)}
            if not a.review:
                reference = read_authorization(approved, 0)
                match_approval(reference, context)
                def guard():
                    recheck_approval(approved, 0, a.hostname, a.host_state_sha256,
                                     hashes, plan, reference)
            if a.recover:
                require(re.fullmatch(r'native\.[0-9a-f]{32}\.json', a.recover), 'invalid journal name')
                require(approved_plan(approved, 0, a.hostname, a.host_state_sha256) == (hashes, plan),
                        'approved context changed before recovery')
                recover(etc, store, 0, reference, store / a.recover, guard=guard)
                print('ROLLED_BACK_STATIC; runtime acceptance not performed'); return 0
            require(not pending(store, 0), 'open transaction requires recovery')
            require('resolver-owner-hint\tUNKNOWN_REGULAR\townership unproven' in pre and
                    any(row.startswith('runtime-ipv4\tMATCH\t') for row in pre) and
                    all(any(row.startswith('service-' + name + '\tNOT_ACTIVE\t') for row in pre)
                        for name in ('NetworkManager', 'systemd-resolved', 'systemd-networkd')),
                    'static resolver/management prerequisites not observed')
            original = snapshot(etc, 0); desired = render(Path('/'), a.hostname, inputs['site.conf'], original)
            context.update(original=digest(encoded(original)), desired=digest(encoded(desired)))
            require(approved_plan(approved, 0, a.hostname, a.host_state_sha256) == (hashes, plan),
                    'approved context changed during review')
            if a.review:
                sys.stdout.write(encoded(context).decode('ascii')); return 0
            require(reference == context, 'approved source/desired state differs')
            release_check(a.release)
            require(approved_plan(approved, 0, a.hostname, a.host_state_sha256) == (hashes, plan),
                    'approved context changed before apply')
            # Operator confirmation additionally attests reviewed G0/G1/G2, static ownership and console/snapshot.
            path = transition(etc, store, 0, context, original, desired, lambda: bool(command(
                '/bin/sh', str(HERE / 'verify-baseline.sh'), '--root=/', '--hostname=' + a.hostname, '--site=' + str(inputs['site.conf']))), guard=guard)
            print('COMMITTED_STATIC ' + path.name + '; runtime hostname/DNS acceptance pending'); return 0
        finally:
            os.close(fd)
    except (OSError, ValueError, subprocess.SubprocessError, IndexError) as exc:
        print('native-install: ' + str(exc) + '; inspect journal before retry', file=sys.stderr)
        return 2


if __name__ == '__main__':
    sys.exit(main())
