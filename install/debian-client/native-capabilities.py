#!/usr/bin/python3
"""Read-only Linux metadata observations; never native write authorization."""
import argparse
import array
import fcntl
import os
import stat
import sys

FILES = ('hostname', 'hosts', 'resolv.conf')
STORAGE = ('var', 'lib', 'sasd', 'provisioning', 'transactions')
# Only the initially proposed local filesystem families; not a durability claim.
FILESYSTEMS = {'ext4', 'xfs'}


def mount_table(lines):
    """Index Linux mountinfo by mount ID, not device number or path prefix."""
    result = {}
    for line in lines:
        left, right = line.rstrip('\n').split(' - ', 1)
        a, b = left.split(), right.split()
        if len(a) < 6 or len(b) != 3 or a[0] in result:
            raise ValueError('invalid mount table')
        result[a[0]] = (b[0], set(a[5].split(',')), set(b[2].split(',')))
    return result


def mount_id(fd):
    with open('/proc/self/fdinfo/%d' % fd, encoding='ascii') as f:
        ids = [line.split()[1] for line in f if line.startswith('mnt_id:')]
    if len(ids) != 1 or not ids[0].isdigit():
        raise ValueError('unknown mount ID')
    return ids[0]


def mount_status(entry):
    kind, options, super_options = entry
    if not kind.isascii() or not all(c.isalnum() or c in '._-' for c in kind):
        return 'UNKNOWN', 'filesystem-name-unknown'
    if 'ro' in options or 'ro' in super_options:
        return 'BLOCK', 'read-only'
    if 'rw' not in options or 'rw' not in super_options:
        return 'UNKNOWN', 'mount-access-unknown'
    if kind not in FILESYSTEMS:
        return 'BLOCK', 'filesystem-outside-initial-profile:' + kind
    return 'OBSERVED', 'local-filesystem-profile:' + kind


def open_child(parent, name, directory):
    """Refuse symlinks and nonmatching object types before opening."""
    before = os.stat(name, dir_fd=parent, follow_symlinks=False)
    check = stat.S_ISDIR if directory else stat.S_ISREG
    if not check(before.st_mode):
        raise ValueError('unexpected file type')
    flags = os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK
    if directory:
        flags |= os.O_DIRECTORY
    fd = os.open(name, flags, dir_fd=parent)
    after = os.fstat(fd)
    if not check(after.st_mode) or (before.st_dev, before.st_ino) != (after.st_dev, after.st_ino):
        os.close(fd)
        raise ValueError('changed object')
    return fd


def file_flags(fd):
    # Linux FS_IOC_GETFLAGS on the explicitly supported 64-bit ABIs.
    if os.uname().machine != 'x86_64' or array.array('L').itemsize != 8:
        raise ValueError('unsupported ioctl ABI')
    data = array.array('L', [0])
    fcntl.ioctl(fd, 0x80086601, data, True)
    return data[0]


def main():
    parser = argparse.ArgumentParser(description=__doc__, allow_abbrev=False)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument('--live', action='store_true')
    source.add_argument('--root')
    args = parser.parse_args()
    root = '/' if args.live else args.root
    if not root.startswith('/') or os.path.normpath(root) != root or (not args.live and root == '/'):
        parser.error('choose a canonical absolute fixture path other than /')
    if not args.live and os.path.realpath(root) != root:
        parser.error('fixture root must not traverse symlinks')
    owner = 0 if args.live else os.geteuid()
    blocked = False
    print('SASD-NATIVE-CAPABILITIES-1\ncheck\tstatus\tvalue')

    def emit(key, status, value):
        nonlocal blocked
        if status in ('BLOCK', 'UNKNOWN'):
            blocked = True
        print('%s\t%s\t%s' % (key, status, value))

    def inspect(fd, key, directory=False, private=False):
        info = os.fstat(fd)
        mode = stat.S_IMODE(info.st_mode)
        valid = info.st_uid == owner and not (mode & 0o7022)
        if private:
            valid = valid and mode == 0o700
        if not directory:
            valid = valid and info.st_nlink == 1 and info.st_size <= 65536
        emit(key + '.basic', 'OBSERVED' if valid else 'BLOCK', 'owner-mode-links-size')
        try:
            attrs = os.listxattr(fd)
            # Do not disclose attribute names or values; any visible attribute is out of scope.
            emit(key + '.xattrs', 'BLOCK' if attrs else 'OBSERVED',
                 'present' if attrs else 'none-visible')
        except OSError:
            emit(key + '.xattrs', 'UNKNOWN', 'attribute-list-failed')
        try:
            flags = file_flags(fd)
            # Extents and indexed directories are ordinary ext4 implementation flags.
            allowed = 0x80000 | (0x1000 if directory else 0)
            emit(key + '.flags', 'BLOCK' if flags & ~allowed else 'OBSERVED', '0x%08x' % flags)
        except (OSError, ValueError):
            emit(key + '.flags', 'UNKNOWN', 'flags-unavailable')
        try:
            status, reason = mount_status(mounts[mount_id(fd)])
            emit(key + '.mount', status, reason)
        except (OSError, ValueError, KeyError, IndexError):
            emit(key + '.mount', 'UNKNOWN', 'mount-unavailable')

    def boundary(parent, child, key):
        try:
            same = mount_id(parent) == mount_id(child)
            emit(key + '.mount-boundary', 'OBSERVED' if same else 'BLOCK',
                 'same-mount' if same else 'separate-mount')
        except (OSError, ValueError, IndexError):
            emit(key + '.mount-boundary', 'UNKNOWN', 'mount-unavailable')

    emit('scope', 'INFO', 'LIVE_READ_ONLY' if args.live else 'FIXTURE_READ_ONLY')
    # Non-root callers cannot establish visibility of all namespaces (trusted.* etc.).
    emit('attribute-visibility', 'UNKNOWN' if os.geteuid() != 0 else 'INFO',
         'unprivileged-incomplete' if os.geteuid() != 0 else 'privileged-not-exhaustive')
    try:
        with open('/proc/self/mountinfo', encoding='utf-8', errors='surrogateescape') as f:
            mounts = mount_table(f)
    except (OSError, ValueError):
        mounts = {}
        emit('mount-table', 'UNKNOWN', 'unavailable')
    try:
        rootfd = os.open(root, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    except OSError:
        emit('root', 'BLOCK', 'unavailable')
        emit('native-apply', 'NOT_AUTHORIZED', 'read-only-observation')
        return 3
    try:
        inspect(rootfd, 'root', directory=True)
        try:
            etc = open_child(rootfd, 'etc', True)
        except (OSError, ValueError):
            emit('etc', 'BLOCK', 'unsafe-or-unavailable')
        else:
            try:
                inspect(etc, 'etc', directory=True)
                boundary(rootfd, etc, 'etc')
                for name in FILES:
                    try:
                        fd = open_child(etc, name, False)
                    except (OSError, ValueError):
                        emit(name, 'BLOCK', 'unsafe-or-unavailable')
                        continue
                    try:
                        inspect(fd, name)
                        boundary(etc, fd, name)
                    finally:
                        os.close(fd)
            finally:
                os.close(etc)
        current = os.dup(rootfd)
        try:
            for part in STORAGE:
                try:
                    child = open_child(current, part, True)
                except (OSError, ValueError):
                    emit('journal-path', 'BLOCK', 'missing-or-unsafe')
                    break
                boundary(current, child, 'journal.' + part)
                os.close(current)
                current = child
                inspect(current, 'journal.' + part, directory=True,
                        private=part == 'transactions')
            else:
                emit('journal-path', 'OBSERVED', 'existing-path-only')
        finally:
            os.close(current)
    finally:
        os.close(rootfd)
    emit('summary', 'BLOCK' if blocked else 'OBSERVED', 'review-required')
    emit('native-apply', 'NOT_AUTHORIZED', 'read-only-observation')
    return 3 if blocked else 0


if __name__ == '__main__':
    sys.exit(main())
