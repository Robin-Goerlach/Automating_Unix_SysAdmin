#!/usr/bin/python3
"""Compare local installation identity with an independently retained lab record."""
import argparse
import hashlib
import os
import re
import stat
import sys
import uuid


def installation_id(value):
    try:
        parsed = uuid.UUID(value)
    except ValueError:
        raise argparse.ArgumentTypeError('expected canonical UUIDv4') from None
    if str(parsed) != value or parsed.version != 4 or parsed.variant != uuid.RFC_4122:
        raise argparse.ArgumentTypeError('expected canonical UUIDv4')
    return value


def hostname(value):
    if len(value) > 63 or '.' not in value or not all(
        re.fullmatch(r'[a-z0-9](?:[a-z0-9-]*[a-z0-9])?', part)
        for part in value.split('.')
    ):
        raise argparse.ArgumentTypeError('expected lowercase R2 FQDN')
    return value


def fingerprint(value):
    if not re.fullmatch(r'[0-9a-f]{64}', value):
        raise argparse.ArgumentTypeError('expected SHA-256 hex')
    return value


def trusted(info, owner):
    return info.st_uid == owner and not (stat.S_IMODE(info.st_mode) & 0o7022)


def read_identity(rootfd, parts, owner):
    """Read a small regular file through checked directory descriptors."""
    current = os.dup(rootfd)
    try:
        for part in parts[:-1]:
            child = os.open(part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=current)
            os.close(current)
            current = child
            if not trusted(os.fstat(current), owner):
                raise ValueError('unsafe directory metadata')
        before = os.stat(parts[-1], dir_fd=current, follow_symlinks=False)
        if not stat.S_ISREG(before.st_mode):
            raise ValueError('unsafe identity file type')
        fd = os.open(parts[-1], os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=current)
        try:
            first = os.fstat(fd)
            if (first.st_dev, first.st_ino) != (before.st_dev, before.st_ino) or not (
                stat.S_ISREG(first.st_mode) and trusted(first, owner)
                and first.st_nlink == 1 and 0 < first.st_size <= 64
            ):
                raise ValueError('unsafe identity file metadata')
            data = os.read(fd, 65)
            last = os.fstat(fd)
            if len(data) != first.st_size or (first.st_size, first.st_mtime_ns, first.st_ctime_ns) != (
                last.st_size, last.st_mtime_ns, last.st_ctime_ns
            ):
                raise ValueError('identity changed during read')
            return data.decode('ascii').removesuffix('\n')
        finally:
            os.close(fd)
    finally:
        os.close(current)


def main():
    parser = argparse.ArgumentParser(description=__doc__, allow_abbrev=False)
    scope = parser.add_mutually_exclusive_group(required=True)
    scope.add_argument('--live', action='store_true')
    scope.add_argument('--root')
    parser.add_argument('--hostname', required=True, type=hostname)
    parser.add_argument('--expected-installation', required=True, type=installation_id)
    parser.add_argument('--expected-fingerprint', type=fingerprint)
    args = parser.parse_args()
    root = '/' if args.live else args.root
    if not args.live and (os.geteuid() == 0 or not root.startswith('/') or root == '/'
                          or os.path.realpath(root) != root):
        parser.error('unprivileged canonical fixture path required')
    owner = 0 if args.live else os.geteuid()
    print('SASD-NATIVE-IDENTITY-1\ncheck\tstatus\tvalue')
    print('scope\tINFO\t' + ('LIVE_READ_ONLY' if args.live else 'FIXTURE_READ_ONLY'))
    print('inventory-host\tINFO\t' + args.hostname)

    def finish(status, reason, code):
        print('binding\t%s\t%s' % (status, reason))
        print('native-apply\tNOT_AUTHORIZED\tidentity-observation-only')
        return code

    try:
        fd = os.open(root, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
        try:
            if not trusted(os.fstat(fd), owner):
                raise ValueError('unsafe root')
            local = read_identity(fd, ('var', 'lib', 'sasd', 'provisioning', 'installation-id'), owner)
            machine = read_identity(fd, ('etc', 'machine-id'), owner)
        finally:
            os.close(fd)
        installation_id(local)
        if not re.fullmatch(r'[0-9a-f]{32}', machine) or machine == '0' * 32:
            raise ValueError('invalid machine identity')
    except (OSError, ValueError, argparse.ArgumentTypeError):
        return finish('UNKNOWN', 'identity-missing-unsafe-or-invalid', 3)
    if local != args.expected_installation:
        return finish('MISMATCH', 'installation-id-differs', 1)
    # Application-scoped correlation, not a credential or proof of identity.
    data = '\0'.join(('SASD-NATIVE-IDENTITY-1', args.hostname, local, machine)).encode('ascii')
    digest = hashlib.sha256(data).hexdigest()
    if args.expected_fingerprint is None:
        print('fingerprint\tOBSERVED\t' + digest)
        return finish('UNBOUND', 'independent-reference-required', 3)
    if digest != args.expected_fingerprint:
        return finish('MISMATCH', 'fingerprint-differs', 1)
    print('fingerprint\tOBSERVED\t' + digest)
    return finish('MATCH', 'reference-corresponds-not-authorization', 0)


if __name__ == '__main__':
    sys.exit(main())
