#!/bin/sh
set -eu
[ "$(id -u)" -ne 0 ] || { echo 'Fixture dispatch test SKIPPED: root'; exit 0; }
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
root=$(mktemp -d /tmp/sasd-debian-lab.XXXXXXXX)
aux=$(mktemp -d); reports=
cleanup(){ for report in $reports; do rm -rf -- "$report"; done; rm -rf -- "$root" "$aux"; }
trap cleanup EXIT
umask 077
mkdir "$root/etc"
printf 'SASD-DEBIAN-FIXTURE-1\n' > "$root/.sasd-fixture"
printf 'old\n' > "$root/etc/hostname"
printf '127.0.0.1 localhost\n127.0.1.1 old.lab.invalid old\n::1 localhost\n' > "$root/etc/hosts"
printf 'nameserver 192.0.2.99\nsearch old.invalid\n' > "$root/etc/resolv.conf"
printf 'dns1=192.0.2.53\nsearch=lab.invalid\n' > "$aux/site"
printf 'workstation\tsite_workstation\tmodern\troles/workstation.tsv\n' > "$aux/roles"
printf 'node.lab.invalid\t192.0.2.40\tdebian\tworkstation\t\tbaseline\n' > "$aux/hosts"
run(){ "$here/install-client.sh" --fixture-apply --root="$root" --hostname=node.lab.invalid --site="$aux/site" --inventory="$aux/hosts" --roles="$aux/roles" "$@"; }
collect(){ report=$(sed -n 's/^Fixture report: //p' "$aux/out"); case "$report" in /tmp/sasd-debian-fixture-report.*) reports="$reports $report" ;; *) exit 1 ;; esac; }
run > "$aux/out"; collect
[ "$(cat "$report/status")" = VERIFIED_FIXTURE ]
[ "$(grep -c FIXTURE_VERIFIED "$report/results.tsv")" -eq 3 ]
grep -q '0020.*WAIT_RUNTIME' "$report/results.tsv"
[ "$(cat "$root/etc/hostname")" = node ]
[ "$(cat "$(cat "$report/transaction")/state")" = COMMITTED ]
(cd "$root/etc" && sha256sum hostname hosts resolv.conf) > "$aux/before"
run > "$aux/out"; collect
[ "$(grep -c '^UNCHANGED ' "$report/apply.log")" -eq 3 ]
(cd "$root/etc" && sha256sum -c "$aux/before")
# Refuse invalid selection without running apply.
rc=0; run --only=0010 > "$aux/out" 2>&1 || rc=$?; [ "$rc" -eq 2 ]
rc=0; run --root=/ > "$aux/out" 2>&1 || rc=$?; [ "$rc" -eq 2 ]
# Explicit live-root and conflicting mode requests are refused independently.
rc=0; "$here/install-client.sh" --fixture-apply --root=/ --hostname=node.lab.invalid --site="$aux/site" --inventory="$aux/hosts" --roles="$aux/roles" > "$aux/out" 2>&1 || rc=$?
[ "$rc" -eq 2 ]; ! grep -q '^Fixture report:' "$aux/out"
rc=0; run --dryrun > "$aux/out" 2>&1 || rc=$?; [ "$rc" -eq 2 ]
# Changed dependencies must be rejected before any write. Isolate the catalog.
mkdir -p "$aux/copy/install" "$aux/copy/bin"
cp -R "$here" "$aux/copy/install/debian-client"
cp "$here/../../bin/sasd-site-inventory" "$aux/copy/bin/"
mkdir -p "$aux/copy/lib/SASD"
cp "$here/../../lib/SASD/Monitor.pm" "$aux/copy/lib/SASD/"
printf '0040\t0010\tverified\n' >> "$aux/copy/install/debian-client/dependencies.tsv"
rc=0; "$aux/copy/install/debian-client/install-client.sh" --fixture-apply --root="$root" --hostname=node.lab.invalid --site="$aux/site" --inventory="$aux/hosts" --roles="$aux/roles" > "$aux/out" 2>&1 || rc=$?
[ "$rc" -eq 2 ]; grep -q 'baseline dependency contract changed' "$aux/out"
! grep -q '^Fixture report:' "$aux/out"
# An open journal must prevent new changes and successful evidence.
open=$(mktemp -d "$root/baseline.XXXXXXXX"); printf 'APPLYING\n' > "$open/state"
rc=0; run > "$aux/out" 2>&1 || rc=$?; [ "$rc" -eq 1 ]; collect
[ "$(cat "$report/status")" = APPLY_FAILED_OR_INTERRUPTED ]; [ ! -e "$report/results.tsv" ]
grep -q 'recovery required' "$report/apply.log"
rm -r "$open"
(cd "$root/etc" && sha256sum -c "$aux/before")
# A changed inventory must block before creating a transaction.
printf 'other.lab.invalid\t192.0.2.40\tdebian\tworkstation\t\tbaseline\n' > "$aux/hosts"
rc=0; run > "$aux/out" 2>&1 || rc=$?; [ "$rc" -eq 2 ]
! grep -q '^Fixture report:' "$aux/out"
(cd "$root/etc" && sha256sum -c "$aux/before")
# A conflict during apply yields no successful evidence.
printf 'node.lab.invalid\t192.0.2.40\tdebian\tworkstation\t\tbaseline\n' > "$aux/hosts"
printf '192.0.2.41 node.lab.invalid node\n' >> "$root/etc/hosts"
rc=0; run > "$aux/out" 2>&1 || rc=$?; [ "$rc" -eq 1 ]; collect
[ "$(cat "$report/status")" = APPLY_FAILED_OR_INTERRUPTED ]
[ ! -e "$report/results.tsv" ]
echo 'Fixture dispatcher tests passed'
