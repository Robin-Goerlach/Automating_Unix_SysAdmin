#!/bin/sh
set -eu
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
tmp=$(mktemp -d); stage=
cleanup(){ [ -z "$stage" ] || rm -rf -- "$stage"; rm -rf -- "$tmp"; }
trap cleanup EXIT
trap 'exit 1' HUP INT TERM
printf 'workstation\tsite_workstation\tmodern\troles/workstation.tsv\n' > "$tmp/roles"
printf 'node.lab.invalid\t192.0.2.40\tdebian\tworkstation\t\tbaseline\n' > "$tmp/hosts"
run(){ "$here/install-client.sh" --hostname=node.lab.invalid --inventory="$tmp/hosts" --roles="$tmp/roles" --site="$here/site.example.conf" "$@"; }
rc=0; run --dryrun > "$tmp/out" || rc=$?
[ "$rc" -eq 3 ]; grep -q 'WAIT_VERIFIED.*0020_' "$tmp/out"
grep -q 'WAIT_VERIFIED.*0790_' "$tmp/out"
run --only=0040 --dryrun > "$tmp/out"
grep -q 'PLANNED.*0030_' "$tmp/out"; grep -q 'PLANNED.*0040_' "$tmp/out"
grep -q 'planned=2 staged=0 pending=0' "$tmp/out"
rc=0; run --only=0020 --dryrun > "$tmp/out" || rc=$?
[ "$rc" -eq 3 ]; grep -q 'WAIT_VERIFIED.*0020_' "$tmp/out"
rc=0; run --apply > "$tmp/out" 2>&1 || rc=$?; [ "$rc" -eq 2 ]
if [ "$(id -u)" -eq 0 ]; then
    rc=0; run --stage > "$tmp/out" 2>&1 || rc=$?; [ "$rc" -eq 2 ]
else
    run --only=0040 --stage > "$tmp/out"
    stage=$(sed -n 's/^Candidate directory: //p' "$tmp/out")
    case "$stage" in /tmp/sasd-debian-stage.*) ;; *) exit 1 ;; esac
    [ "$(grep -c STAGED "$stage/results.tsv")" -eq 2 ]
    while IFS="$(printf '\t')" read -r id task status hash; do
        [ "$status" = STAGED ] || continue
        actual=$(sha256sum < "$stage/${id}_$task.candidate")
        [ "${actual%% *}" = "$hash" ]
    done < "$stage/results.tsv"
    rm -rf -- "$stage"; stage=
fi
# Exercise the archived planner without a surrounding repository.
"$here/package.sh" "$tmp/release"
mkdir "$tmp/unpack"
tar -xzf "$tmp/release/sasd-debian-client.tar.gz" -C "$tmp/unpack"
cmp "$here/../../bin/sasd-site-inventory" "$tmp/unpack/debian-client/lib/sasd-site-inventory"
"$tmp/unpack/debian-client/install-client.sh" --hostname=node.lab.invalid --inventory="$tmp/hosts" --roles="$tmp/roles" --only=0040 --dryrun > "$tmp/archive"
grep -q 'planned=2 staged=0 pending=0' "$tmp/archive"
echo 'Inventory-bound dispatcher tests passed'
