#!/bin/sh
set -eu
[ "$(id -u)" -ne 0 ] || { echo 'Recovery test SKIPPED: root'; exit 0; }
Here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
. "$Here/lib/transaction.sh"
root=$(mktemp -d /tmp/sasd-debian-lab.XXXXXXXX)
trap 'rm -rf -- "$root"' EXIT
umask 077
mkdir "$root/etc"
printf 'SASD-DEBIAN-FIXTURE-1\n' > "$root/.sasd-fixture"
fixture_check
work=$(mktemp -d "$root/baseline.XXXXXXXX")
mkdir "$work/original" "$work/check" "$work/check/etc"
for name in hostname hosts resolv.conf; do
    printf 'original %s\n' "$name" > "$work/original/$name"
    printf 'desired %s\n' "$name" > "$work/check/etc/$name"
    cp -p "$work/original/$name" "$root/etc/$name"
done
manifest "$work/original" > "$work/original.tsv"
manifest "$work/check/etc" > "$work/desired.tsv"
state_set APPLYING
# Simulate interrupted apply after one replacement.
cp -p "$work/check/etc/hostname" "$root/etc/hostname"
recover(){ "$Here/recover-baseline.sh" --root="$root" --transaction="${work##*/}" "$@"; }
reject(){ rc=0; "$@" >/dev/null 2>&1 || rc=$?; [ "$rc" -eq 2 ]; }
[ "$(pending_transaction)" = "$work" ]
before=$(manifest "$root/etc"); recover --dryrun
[ "$(manifest "$root/etc")" = "$before" ]; [ "$(state_get "$work")" = APPLYING ]
# An independently edited target must never be overwritten.
printf 'external edit\n' > "$root/etc/hosts"
before=$(manifest "$root/etc"); reject recover --apply; [ "$(manifest "$root/etc")" = "$before" ]
cp -p "$work/original/hosts" "$root/etc/hosts"
# Tampered backup or manifest mismatch must stop before any write.
cp -p "$work/original/hosts" "$work/saved"
printf 'tampered\n' > "$work/original/hosts"
before=$(manifest "$root/etc"); reject recover --apply; [ "$(manifest "$root/etc")" = "$before" ]
mv "$work/saved" "$work/original/hosts"
# An active writer excludes recovery.
(exec 8< "$root"; flock -x 8; reject recover --apply)
# Multiple open transactions are ambiguous.
second=$(mktemp -d "$root/baseline.XXXXXXXX"); printf 'APPLYING\n' > "$second/state"
reject recover --apply; rm -r "$second"
# Recovery can continue from a partly restored ROLLING_BACK journal.
state_set ROLLING_BACK
recover --apply
[ "$(manifest "$root/etc")" = "$(cat "$work/original.tsv")" ]
[ "$(state_get "$work")" = ROLLED_BACK ]; [ -z "$(pending_transaction)" ]
reject recover --apply
state_set COMMITTED; reject recover --apply
reject "$Here/recover-baseline.sh" --root=/ --transaction="${work##*/}" --apply
echo 'Fixture recovery tests passed'
