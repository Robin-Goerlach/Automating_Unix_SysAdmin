#!/usr/bin/python3
"""Review and execute a reference-bound baseline in a private V2 fixture only."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys
import tempfile

HERE = Path(__file__).resolve().parent
NAMES = ('hostname', 'hosts', 'resolv.conf')
RUNTIME = ('install-client.sh dispatch-planned.sh dispatch-fixture.sh plan-client.pl '
           'native-preflight.pl native-capabilities.py native-identity.py prepare-native.sh '
           'collect-native.sh verify-dns.pl lab-install.py native-install.py plan-packages.py plan-services.py plan-communications.py plan-storage.py plan-shell.py plan-security.py plan-audits.py dependencies.tsv verify-baseline.sh '
           'apply-baseline.sh recover-baseline.sh lib/transaction.sh lib/task.sh lib/policy.sh lib/baseline-render.sh '
           'checklist.tsv site.example.conf package-policy.tsv package-profiles.tsv inventory-fields.tsv').split()


def digest(data):
    return hashlib.sha256(data).hexdigest()


def read_file(path, limit=4 * 1024 * 1024):
    info = path.lstat()
    if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1 or info.st_size > limit:
        raise ValueError('unsafe or oversized input')
    with path.open('rb') as stream:
        data = stream.read(limit + 1)
    if len(data) != info.st_size:
        raise ValueError('input size changed')
    return data


def release_digest():
    paths = RUNTIME + ['tasks/' + p.name for p in sorted((HERE / 'tasks').iterdir())]
    validator = HERE / 'lib/sasd-site-inventory'
    if not validator.exists() and not validator.is_symlink():
        validator = HERE / '../../bin/sasd-site-inventory'
    rows = []
    for name in sorted(paths + ['lib/sasd-site-inventory']):
        path = validator if name == 'lib/sasd-site-inventory' else HERE / name
        rows.append([name, stat.S_IMODE(path.lstat().st_mode), digest(read_file(path))])
    return digest(json.dumps(rows, separators=(',', ':')).encode('ascii'))


def run(*args):
    return subprocess.run(args, text=True, capture_output=True, check=False)


def manifest(root, desired=None):
    rows = ['SASD-FILE-METADATA-1', 'file\tuid\tgid\tmode\tsize\tsha256']
    for name in NAMES:
        path = root / 'etc' / name
        info = path.lstat()
        content = read_file(path, 65536)
        if desired is not None:
            content = read_file(desired / name, 65536)
        rows.append('\t'.join(map(str, (name, info.st_uid, info.st_gid,
                                      format(stat.S_IMODE(info.st_mode), 'o'),
                                      len(content), digest(content)))))
    return digest(('\n'.join(rows) + '\n').encode('ascii'))


def unique_pairs(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError('duplicate reference field')
        result[key] = value
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__, allow_abbrev=False)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--review', action='store_true')
    mode.add_argument('--apply-fixture', action='store_true')
    for name in ('root', 'hostname', 'site', 'inventory', 'roles', 'installation', 'fingerprint'):
        parser.add_argument('--' + name, required=True)
    parser.add_argument('--reference')
    a = parser.parse_args()
    root = Path(a.root)
    if (os.geteuid() == 0 or not re.fullmatch(r'/tmp/sasd-debian-lab\.[A-Za-z0-9]+', a.root)
            or str(root.resolve()) != a.root or bool(a.reference) != a.apply_fixture):
        parser.error('private V2 fixture and explicit mode required')
    try:
        for path in (root, root / 'etc'):
            info = path.lstat()
            if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.geteuid() or stat.S_IMODE(info.st_mode) != 0o700:
                raise ValueError('unsafe fixture')
        if read_file(root / '.sasd-fixture', 64) != b'SASD-DEBIAN-FIXTURE-2\n':
            raise ValueError('V2 fixture required')
        with tempfile.TemporaryDirectory(prefix='sasd-lab-input.') as tmp:
            inputs = {}
            hashes = {}
            for key in ('site', 'inventory', 'roles'):
                data = read_file(Path(getattr(a, key)))
                inputs[key] = str(Path(tmp) / key)
                Path(inputs[key]).write_bytes(data)
                hashes[key] = digest(data)
            common = ['--hostname=' + a.hostname] + ['--' + key + '=' + inputs[key] for key in inputs]
            identity = run(str(HERE / 'native-identity.py'), '--root=' + a.root,
                           '--hostname=' + a.hostname, '--expected-installation=' + a.installation,
                           '--expected-fingerprint=' + a.fingerprint)
            if identity.returncode != 0:
                raise ValueError('identity reference did not match')
            before = manifest(root)
            release = release_digest()
            rehearsal = run(str(HERE / 'prepare-native.sh'), '--source-root=' + a.root, *common)
            match = re.findall(r'^Native review: (/tmp/sasd-native-review\.[A-Za-z0-9]+)$', rehearsal.stdout, re.M)
            if len(match) != 1:
                raise ValueError('missing rehearsal report')
            review = Path(match[0])
            if review.is_symlink() or review.stat().st_uid != os.geteuid() or stat.S_IMODE(review.stat().st_mode) != 0o700:
                raise ValueError('unsafe rehearsal report')
            try:
                if rehearsal.returncode != 0 or read_file(review / 'status') != b'PREPARED_NOT_AUTHORIZED\n':
                    raise ValueError('rehearsal refused')
                if manifest(root) != before or any(read_file(root / 'etc' / n) != read_file(review / 'original' / n) for n in NAMES):
                    raise ValueError('source changed during rehearsal')
                expected = {'format': 'SASD-LAB-REFERENCE-1', 'scope': 'FIXTURE_ONLY',
                            'hostname': a.hostname, 'identity': a.fingerprint, 'release': release,
                            'inputs': hashes, 'plan': digest(read_file(review / 'plan.tsv')),
                            'original': before, 'desired': manifest(root, review / 'desired')}
            finally:
                shutil.rmtree(review)
            if release_digest() != release:
                raise ValueError('release changed during review')
            if a.review:
                print(json.dumps(expected, sort_keys=True, indent=2))
                return 0
            reference = json.loads(read_file(Path(a.reference), 16384), object_pairs_hook=unique_pairs)
            if reference != expected:
                raise ValueError('review differs from supplied reference')
            result = run(str(HERE / 'dispatch-fixture.sh'), '--fixture-apply', '--root=' + a.root,
                         *common, '--expect-original=' + expected['original'],
                         '--expect-desired=' + expected['desired'])
            sys.stdout.write(result.stdout)
            sys.stderr.write(result.stderr)
            if result.returncode:
                return 1
            print('REFERENCE_MATCHED_FIXTURE_ONLY; native-apply NOT_AUTHORIZED')
            return 0
    except (OSError, ValueError, UnicodeError) as exc:
        print('lab-install: ' + str(exc), file=sys.stderr)
        return 2


if __name__ == '__main__':
    os.umask(0o077)
    sys.exit(main())
