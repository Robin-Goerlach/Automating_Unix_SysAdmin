#!/bin/sh
# Validate versioned journal metadata and directory binding without native writes.
set -eu
[ "$(id -u)" -ne 0 ] || { echo 'Metadata test SKIPPED: root'; exit 0; }
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
. "$here/lib/transaction.sh"
root=$(mktemp -d /tmp/sasd-debian-lab.XXXXXXXX)
other=$(mktemp -d /tmp/sasd-debian-lab.XXXXXXXX)
aux=$(mktemp -d)
trap 'rm -rf -- "$root" "$other" "$aux"' EXIT
umask 077
mkdir "$root/etc"
printf 'SASD-DEBIAN-FIXTURE-1\n' > "$root/.sasd-fixture"
fixture_check
work=$(mktemp -d "$root/baseline.XXXXXXXX")
mkdir "$work/original" "$work/check" "$work/check/etc"
for name in hostname hosts resolv.conf; do
    printf 'original %s\n' "$name" > "$work/original/$name"
    printf 'desired %s\n' "$name" > "$work/check/etc/$name"
    chmod 640 "$work/original/$name" "$work/check/etc/$name"
    cp -p "$work/original/$name" "$root/etc/$name"
done
manifest "$work/original" > "$work/original.tsv"
manifest "$work/check/etc" > "$work/desired.tsv"
record_metadata; sync_prepared; state_set APPLYING
cp -p "$work/check/etc/hostname" "$root/etc/hostname"
recover(){ "$here/recover-baseline.sh" --root="$root" --transaction="${work##*/}" "$@"; }
reject(){ rc=0; recover --apply > "$aux/out" 2>&1 || rc=$?; [ "$rc" -eq 2 ]; [ "$(metadata_manifest "$root/etc")" = "$before" ]; }
before=$(metadata_manifest "$root/etc")
recover --dryrun
# Missing metadata or altered identity/version never falls back to old recovery.
for name in context.tsv original-metadata.tsv desired-metadata.tsv; do
    mv "$work/$name" "$aux/saved"; reject
    cp -p "$aux/saved" "$work/$name"; printf 'unexpected\n' >> "$work/$name"; reject
    mv "$aux/saved" "$work/$name"
done
# A change to basic metadata alone is a conflict.
chmod 600 "$root/etc/hosts"; before=$(metadata_manifest "$root/etc"); reject
chmod 640 "$root/etc/hosts"; before=$(metadata_manifest "$root/etc")
# A changed snapshot mode is rejected even if legacy content manifest is rewritten.
chmod 600 "$work/original/hosts"; manifest "$work/original" > "$work/original.tsv"; reject
chmod 640 "$work/original/hosts"; manifest "$work/original" > "$work/original.tsv"
# Identical contents copied to another private fixture do not transfer authority.
cp -R -p "$root/." "$other/"
rc=0; "$here/recover-baseline.sh" --root="$other" --transaction="${work##*/}" --apply > "$aux/out" 2>&1 || rc=$?
[ "$rc" -eq 2 ]; [ "$(metadata_manifest "$other/etc")" = "$before" ]
# Replacing the etc directory with a byte-identical copy also invalidates context.
mv "$root/etc" "$root/old-etc"; cp -R -p "$root/old-etc" "$root/etc"; reject
rm -r "$root/etc"; mv "$root/old-etc" "$root/etc"
recover --apply
[ "$(metadata_manifest "$root/etc")" = "$(cat "$work/original-metadata.tsv")" ]
[ "$(state_get "$work")" = ROLLED_BACK ]
echo 'Versioned metadata and fixture context tests passed'
