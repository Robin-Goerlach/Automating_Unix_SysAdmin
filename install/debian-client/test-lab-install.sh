#!/bin/sh
# Reference-bound installation and stale-reference rejection in a private V2 tree.
set -eu
[ -x /usr/bin/python3 ] || { echo 'Lab install test SKIPPED: python3 unavailable'; exit 0; }
[ "$(id -u)" -ne 0 ] || { echo 'Lab install test SKIPPED: root'; exit 0; }
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
root=$(mktemp -d /tmp/sasd-debian-lab.XXXXXXXX)
aux=$(mktemp -d); reports=
cleanup(){ for report in $reports; do rm -rf -- "$report"; done; rm -rf -- "$root" "$aux"; }
trap cleanup EXIT
umask 077
mkdir "$root/etc"; mkdir -p "$root/var/lib/sasd/provisioning/transactions"
printf 'SASD-DEBIAN-FIXTURE-2\n' > "$root/.sasd-fixture"
printf 'ID=debian\nVERSION_ID="13"\n' > "$root/etc/os-release"
printf 'old\n' > "$root/etc/hostname"
printf '127.0.0.1 localhost\n127.0.1.1 old.lab.invalid old\n::1 localhost\n' > "$root/etc/hosts"
printf 'nameserver 192.0.2.99\nsearch old.invalid\n' > "$root/etc/resolv.conf"
iid=12345678-1234-4234-8234-123456789abc
printf '%s\n' "$iid" > "$root/var/lib/sasd/provisioning/installation-id"
printf '0123456789abcdef0123456789abcdef\n' > "$root/etc/machine-id"
printf 'workstation\tsite_workstation\tmodern\troles/workstation.tsv\n' > "$aux/roles"
printf 'node.lab.invalid\t192.0.2.40\tdebian\tworkstation\t\tbaseline\n' > "$aux/hosts"
cp "$here/site.example.conf" "$aux/site"
rc=0; "$here/native-identity.py" --root="$root" --hostname=node.lab.invalid --expected-installation="$iid" > "$aux/id" || rc=$?; [ "$rc" -eq 3 ]
fp=$(awk -F '\t' '$1=="fingerprint" {print $3}' "$aux/id")
run(){ "$here/lab-install.py" --root="$root" --hostname=node.lab.invalid --site="$aux/site" --inventory="$aux/hosts" --roles="$aux/roles" --installation="$iid" --fingerprint="$fp" "$@"; }
manifest(){ (cd "$root/etc" && sha256sum hostname hosts resolv.conf && stat -c '%n %u:%g:%a' hostname hosts resolv.conf); }
manifest > "$aux/before"
run --review > "$aux/reference"
manifest > "$aux/after"; cmp "$aux/before" "$aux/after"
reject(){ rc=0; run --apply-fixture --reference="$aux/reference" > "$aux/out" 2>&1 || rc=$?; [ "$rc" -eq 2 ]; ! grep -q '^Fixture report:' "$aux/out"; }
# Any byte change in the approved input or source invalidates the reference.
printf '# changed\n' >> "$aux/site"; reject; cp "$here/site.example.conf" "$aux/site"
printf '# changed\n' >> "$root/etc/hosts"; reject; sed -i '$d' "$root/etc/hosts"
printf '1234567890abcdef0123456789abcdef\n' > "$root/etc/machine-id"; reject
printf '0123456789abcdef0123456789abcdef\n' > "$root/etc/machine-id"
cp "$aux/reference" "$aux/saved"
# Change release digest in the independent reference.
/usr/bin/python3 - "$aux/reference" <<'PY'
import json,sys
p=sys.argv[1]; data=json.load(open(p)); data['release']='0'*64
with open(p,'w') as f: json.dump(data,f)
PY
reject
printf '{"format":"a","format":"b"}\n' > "$aux/reference"; reject
cp "$aux/saved" "$aux/reference"
manifest > "$aux/after"; cmp "$aux/before" "$aux/after"
# The transaction itself checks the pre-mutation manifests under its lock.
zero=$(printf '%064d' 0)
rc=0; "$here/apply-baseline.sh" --root="$root" --hostname=node.lab.invalid --site="$aux/site" --apply --expect-original="$zero" --expect-desired="$zero" > "$aux/out" 2>&1 || rc=$?
[ "$rc" -eq 2 ]; grep -q 'reference original mismatch' "$aux/out"
manifest > "$aux/after"; cmp "$aux/before" "$aux/after"
original=$(/usr/bin/python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["original"])' "$aux/reference")
rc=0; "$here/apply-baseline.sh" --root="$root" --hostname=node.lab.invalid --site="$aux/site" --apply --expect-original="$original" --expect-desired="$zero" > "$aux/out" 2>&1 || rc=$?
[ "$rc" -eq 2 ]; grep -q 'reference desired mismatch' "$aux/out"
manifest > "$aux/after"; cmp "$aux/before" "$aux/after"
run --apply-fixture --reference="$aux/reference" > "$aux/out"
report=$(sed -n 's/^Fixture report: //p' "$aux/out"); reports="$reports $report"
[ "$(cat "$report/status")" = VERIFIED_FIXTURE ]
grep -q '^REFERENCE_MATCHED_FIXTURE_ONLY;' "$aux/out"
[ "$(cat "$root/etc/hostname")" = node ]
[ "$(cat "$(cat "$report/transaction")/state")" = COMMITTED ]
# Old reference cannot be reused for a changed source.
reject
run --review > "$aux/reference"
run --apply-fixture --reference="$aux/reference" > "$aux/out"
report=$(sed -n 's/^Fixture report: //p' "$aux/out"); reports="$reports $report"
[ "$(grep -c '^UNCHANGED ' "$report/apply.log")" -eq 3 ]
echo 'Reference-bound lab installation tests passed'
