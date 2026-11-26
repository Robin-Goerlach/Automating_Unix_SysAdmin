#!/bin/sh
# Independent reference matching on disposable data, no native identity writes.
set -eu
[ -x /usr/bin/python3 ] || { echo 'Native identity test SKIPPED: python3 unavailable'; exit 0; }
[ "$(id -u)" -ne 0 ] || { echo 'Native identity test SKIPPED: root'; exit 0; }
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
tmp=$(mktemp -d); trap 'rm -rf -- "$tmp"' EXIT
umask 077
root=$tmp/source
mkdir -p "$root/etc" "$root/var/lib/sasd/provisioning"
local=$root/var/lib/sasd/provisioning/installation-id
machine=$root/etc/machine-id
id1=12345678-1234-4234-8234-123456789abc
id2=12345678-1234-4234-8234-123456789def
mid=0123456789abcdef0123456789abcdef
printf '%s\n' "$id1" > "$local"; printf '%s\n' "$mid" > "$machine"
run(){ rc=0; "$here/native-identity.py" --root="$root" --hostname=node.lab.invalid --expected-installation="$id1" "$@" > "$tmp/out" 2>&1 || rc=$?; }
run; [ "$rc" -eq 3 ]; grep -q 'binding.*UNBOUND' "$tmp/out"
digest=$(awk -F '\t' '$1=="fingerprint" {print $3}' "$tmp/out")
[ "${#digest}" -eq 64 ]; ! grep -q "$mid\|$id1" "$tmp/out"
check(){ run --expected-fingerprint="$digest"; [ "$rc" -eq "$1" ]; grep -q "binding.*$2" "$tmp/out"; grep -q 'native-apply.*NOT_AUTHORIZED' "$tmp/out"; }
check 0 MATCH
# Same machine-id with another installation-id cannot match the reference.
printf '%s\n' "$id2" > "$local"; check 1 MISMATCH
printf '%s\n' "$id1" > "$local"
printf '%032d\n' 1 > "$machine"; check 1 MISMATCH
printf '%032d\n' 0 > "$machine"; check 3 UNKNOWN
printf '%s\n' "$mid" > "$machine"
chmod 666 "$local"; check 3 UNKNOWN; chmod 600 "$local"
ln "$local" "$tmp/link"; check 3 UNKNOWN; rm "$tmp/link"
mv "$local" "$tmp/saved"; ln -s "$tmp/saved" "$local"; check 3 UNKNOWN; rm "$local"; mv "$tmp/saved" "$local"
chmod 777 "$root/etc"; check 3 UNKNOWN; chmod 700 "$root/etc"
mv "$machine" "$tmp/saved"; check 3 UNKNOWN; mv "$tmp/saved" "$machine"
printf '%s\n\n' "$mid" > "$machine"; check 3 UNKNOWN; printf '%s\n' "$mid" > "$machine"
check 0 MATCH
rc=0; "$here/native-identity.py" --root=/ --hostname=node.lab.invalid --expected-installation="$id1" > "$tmp/out" 2>&1 || rc=$?; [ "$rc" -eq 2 ]
rc=0; "$here/native-identity.py" --root="$root" --hostname=node.lab.invalid --expected-installation=invalid > "$tmp/out" 2>&1 || rc=$?; [ "$rc" -eq 2 ]
echo 'Native installation identity tests passed'
