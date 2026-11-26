#!/bin/sh
# Real Linux read-only observations on private fixtures; no mounts or native writes.
set -eu
[ -x /usr/bin/python3 ] || { echo 'Native capabilities test SKIPPED: python3 unavailable'; exit 0; }
[ "$(id -u)" -ne 0 ] || { echo 'Native capabilities test SKIPPED: root'; exit 0; }
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
tmp=$(mktemp -d); trap 'rm -rf -- "$tmp"' EXIT
umask 077
mkdir "$tmp/etc"
mkdir -p "$tmp/var/lib/sasd/provisioning/transactions"
for file in hostname hosts resolv.conf; do printf 'fixture\n' > "$tmp/etc/$file"; done
run(){ rc=0; /usr/bin/python3 "$here/native-capabilities.py" --root="$tmp" > "$tmp/out" || rc=$?; [ "$rc" -eq 3 ]; grep -q 'native-apply.*NOT_AUTHORIZED' "$tmp/out"; }
run
grep -q 'scope.*FIXTURE_READ_ONLY' "$tmp/out"
grep -q 'attribute-visibility.*UNKNOWN' "$tmp/out"
grep -q 'journal-path.*OBSERVED' "$tmp/out"
grep -q 'hostname.basic.*OBSERVED' "$tmp/out"
grep -q 'hostname.xattrs.*none-visible' "$tmp/out"
# Real xattr and POSIX ACL, not synthetic command output. If the disposable
# filesystem does not implement the required feature, classify this native
# observation as SKIPPED rather than converting an environment limitation into
# a false implementation failure.
rc=0
/usr/bin/python3 - "$tmp/etc/hosts" <<'PY' || rc=$?
import errno, os, sys
try:
    os.setxattr(sys.argv[1], 'user.sasd-test', b'private-test-value')
except OSError as exc:
    if exc.errno in (errno.EINVAL, errno.ENOTSUP, errno.EOPNOTSUPP):
        raise SystemExit(77)
    raise
PY
if [ "$rc" -eq 77 ]; then
    echo 'Native capability observation tests SKIPPED: user xattrs unavailable'
    exit 0
fi
run; grep -q 'hosts.xattrs.*BLOCK.*present' "$tmp/out"
! grep -q 'private-test-value\|user.sasd-test' "$tmp/out"
rc=0
/usr/bin/python3 - "$tmp/etc/hosts" <<'PY' || rc=$?
import errno, os, struct, sys
p=sys.argv[1]
os.removexattr(p, 'user.sasd-test')
acl=struct.pack('<I', 2)+b''.join(struct.pack('<HHI', *v) for v in [(1,6,0xffffffff),(2,4,65533),(4,4,0xffffffff),(16,4,0xffffffff),(32,0,0xffffffff)])
try:
    os.setxattr(p, 'system.posix_acl_access', acl)
except OSError as exc:
    if exc.errno in (errno.EINVAL, errno.ENOTSUP, errno.EOPNOTSUPP):
        raise SystemExit(77)
    raise
PY
if [ "$rc" -eq 77 ]; then
    echo 'Native capability observation tests SKIPPED: POSIX ACL xattrs unavailable'
    exit 0
fi
run; grep -q 'hosts.xattrs.*BLOCK.*present' "$tmp/out"
/usr/bin/python3 - "$tmp/etc/hosts" <<'PY'
import os, sys
os.removexattr(sys.argv[1], 'system.posix_acl_access')
PY
chmod 600 "$tmp/etc/hosts"
# Basic unsafe metadata and unsafe types.
chmod 666 "$tmp/etc/hosts"; run; grep -q 'hosts.basic.*BLOCK' "$tmp/out"; chmod 600 "$tmp/etc/hosts"
ln "$tmp/etc/hosts" "$tmp/hardlink"; run; grep -q 'hosts.basic.*BLOCK' "$tmp/out"; rm "$tmp/hardlink"
mv "$tmp/etc/resolv.conf" "$tmp/saved"; ln -s "$tmp/saved" "$tmp/etc/resolv.conf"
run; grep -q '^resolv.conf[[:space:]]BLOCK' "$tmp/out"; rm "$tmp/etc/resolv.conf"
mkfifo "$tmp/etc/resolv.conf"; run; grep -q '^resolv.conf[[:space:]]BLOCK' "$tmp/out"; rm "$tmp/etc/resolv.conf"
mv "$tmp/saved" "$tmp/etc/resolv.conf"
chmod 755 "$tmp/var/lib/sasd/provisioning/transactions"; run; grep -q 'journal.transactions.basic.*BLOCK' "$tmp/out"
rmdir "$tmp/var/lib/sasd/provisioning/transactions"; run; grep -q 'journal-path.*BLOCK' "$tmp/out"
[ ! -e "$tmp/var/lib/sasd/provisioning/transactions" ]
# Exercise mount policy with representative mountinfo records, no mount operation.
/usr/bin/python3 -B - "$here/native-capabilities.py" <<'PY'
import importlib.util, sys
spec=importlib.util.spec_from_file_location('probe',sys.argv[1]); m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
t=m.mount_table(['25 1 8:1 / / rw - ext4 /dev/test rw\n','26 25 8:1 /file /etc/hosts rw - ext4 /dev/test rw\n','27 1 0:1 / /tmp rw - tmpfs tmpfs rw\n','28 1 8:2 / /var ro - xfs /dev/test ro\n'])
assert m.mount_status(t['25'])[0]=='OBSERVED'
assert m.mount_status(t['27'])[0]=='BLOCK'
assert m.mount_status(t['28'])[0]=='BLOCK'
assert m.mount_status(('ext4',{'rw'},{'ro'}))[0]=='BLOCK'
try: m.mount_table(['malformed'])
except ValueError: pass
else: raise AssertionError('bad table accepted')
PY
rc=0; /usr/bin/python3 "$here/native-capabilities.py" --root=/ > "$tmp/out" 2>&1 || rc=$?; [ "$rc" -eq 2 ]
echo 'Native capability observation tests passed'
