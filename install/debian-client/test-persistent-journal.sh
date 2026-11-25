#!/bin/sh
# Exercise the future journal directory layout in a disposable unprivileged tree.
set -eu
[ "$(id -u)" -ne 0 ] || { echo 'Persistent layout test SKIPPED: root'; exit 0; }
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
. "$here/lib/transaction.sh"
root=$(mktemp -d /tmp/sasd-debian-lab.XXXXXXXX)
aux=$(mktemp -d); report=
cleanup(){ [ -z "$report" ] || rm -rf -- "$report"; rm -rf -- "$root" "$aux"; }
trap cleanup EXIT
umask 077
mkdir "$root/etc"
printf 'SASD-DEBIAN-FIXTURE-2\n' > "$root/.sasd-fixture"
printf 'old\n' > "$root/etc/hostname"
printf '127.0.0.1 localhost\n127.0.1.1 old.lab.invalid old\n::1 localhost\n' > "$root/etc/hosts"
printf 'nameserver 192.0.2.99\nsearch old.invalid\n' > "$root/etc/resolv.conf"
chmod 640 "$root/etc/hosts"
printf 'dns1=192.0.2.53\nsearch=lab.invalid\n' > "$aux/site"
printf 'workstation\tsite_workstation\tmodern\troles/workstation.tsv\n' > "$aux/roles"
printf 'node.lab.invalid\t192.0.2.40\tdebian\tworkstation\t\tbaseline\n' > "$aux/hosts"
store=$root/var/lib/sasd/provisioning/transactions
run(){ "$here/apply-baseline.sh" --root="$root" --hostname=node.lab.invalid --site="$aux/site" "$@"; }
reject(){ rc=0; "$@" > "$aux/rejected" 2>&1 || rc=$?; [ "$rc" -eq 2 ]; }
# No implicit creation or fallback to the legacy layout.
reject run --apply; [ ! -e "$root/var" ]
mkdir -p "$store"
fixture_check; [ "$journal_parent" = "$store" ]
before=$(metadata_manifest "$root/etc")
chmod 755 "$store"; reject run --apply; chmod 700 "$store"
mv "$store" "$aux/saved-store"; ln -s "$aux/saved-store" "$store"
reject run --apply; rm "$store"; mv "$aux/saved-store" "$store"
printf 'SASD-DEBIAN-FIXTURE-1\n' > "$root/.sasd-fixture"; reject run --apply
printf 'SASD-DEBIAN-FIXTURE-2\n' > "$root/.sasd-fixture"
legacy=$(mktemp -d "$root/baseline.XXXXXXXX"); reject run --apply; rmdir "$legacy"
empty=$(mktemp -d "$store/baseline.XXXXXXXX"); reject run --apply; rmdir "$empty"
[ "$(metadata_manifest "$root/etc")" = "$before" ]
# Force a synchronization failure at the separate journal parent before mutation.
mkdir "$aux/copy"; cp -R "$here/lib" "$aux/copy/"; cp "$here/apply-baseline.sh" "$here/verify-baseline.sh" "$aux/copy/"
sed 's~^sync_paths(){.*~sync_paths(){ [ "$#" -ne 1 ] || [ "$1" != "$journal_parent" ] || return 1; /usr/bin/sync -- "$@"; }~' "$here/lib/transaction.sh" > "$aux/copy/lib/transaction.sh"
reject "$aux/copy/apply-baseline.sh" --root="$root" --hostname=node.lab.invalid --site="$aux/site" --apply
grep -q 'cannot synchronize recovery evidence' "$aux/rejected"
[ "$(metadata_manifest "$root/etc")" = "$before" ]
[ "$(cat "$store"/baseline.*/state)" = PREPARING ]
cp "$here/lib/transaction.sh" "$aux/copy/lib/transaction.sh"
# Kill only the private test process at the final verification step.
cat > "$aux/copy/verify-baseline.sh" <<'VERIFY'
#!/bin/sh
case "$1" in */check) exit 0 ;; *) kill -KILL "$PPID" ;; esac
VERIFY
chmod +x "$aux/copy/verify-baseline.sh"
rc=0; "$aux/copy/apply-baseline.sh" --root="$root" --hostname=node.lab.invalid --site="$aux/site" --apply > "$aux/killed" 2>&1 || rc=$?
[ "$rc" -eq 137 ]; [ "$(metadata_manifest "$root/etc")" != "$before" ]
work=$(pending_transaction); [ "${work%/*}" = "$store" ]; [ "$(state_get "$work")" = APPLYING ]
grep -qx 'layout[[:space:]]persistent-fixture' "$work/context.tsv"
reject run --apply; grep -q 'recovery required' "$aux/rejected"
recover(){ "$here/recover-baseline.sh" --root="$root" --transaction="${work##*/}" "$@"; }
recover --dryrun
changed=$(metadata_manifest "$root/etc")
# A renamed journal store with a new parent inode must not become authority.
mv "$store" "$store.old"; mkdir "$store"; mv "$store.old/${work##*/}" "$work"
reject recover --apply; [ "$(metadata_manifest "$root/etc")" = "$changed" ]
mv "$work" "$store.old/"; rmdir "$store"; mv "$store.old" "$store"
recover --apply
[ "$(metadata_manifest "$root/etc")" = "$before" ]; [ "$(state_get "$work")" = ROLLED_BACK ]
# Real inventory-bound dispatcher uses the same persistent layout.
"$here/install-client.sh" --fixture-apply --root="$root" --hostname=node.lab.invalid --site="$aux/site" --inventory="$aux/hosts" --roles="$aux/roles" > "$aux/out"
report=$(sed -n 's/^Fixture report: //p' "$aux/out")
case "$report" in /tmp/sasd-debian-fixture-report.*) ;; *) report=; exit 1 ;; esac
[ "$(cat "$report/status")" = VERIFIED_FIXTURE ]
committed=$(cat "$report/transaction"); [ "${committed%/*}" = "$store" ]
[ "$(cat "$committed/state")" = COMMITTED ]
[ -z "$(find "$root" -maxdepth 1 -name 'baseline.*' -print)" ]
installed=$(metadata_manifest "$root/etc")
run --apply > "$aux/again"; [ "$(grep -c '^UNCHANGED ' "$aux/again")" -eq 3 ]
[ "$(metadata_manifest "$root/etc")" = "$installed" ]
[ -z "$(pending_transaction)" ]
reject "$here/apply-baseline.sh" --root=/ --hostname=node.lab.invalid --site="$aux/site" --apply
echo 'Persistent fixture journal layout, interrupted recovery and dispatcher tests passed'
