#!/bin/sh
# Exercise real fsync calls and injected failures in a private script copy.
set -eu
[ "$(id -u)" -ne 0 ] || { echo 'Durability test SKIPPED: root'; exit 0; }
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
aux=$(mktemp -d); root=
cleanup(){ [ -z "$root" ] || rm -rf -- "$root"; rm -rf -- "$aux"; }
trap cleanup EXIT
trap 'exit 1' HUP INT TERM
umask 077
mkdir "$aux/copy"
cp -R "$here/lib" "$aux/copy/"
cp "$here/apply-baseline.sh" "$here/verify-baseline.sh" "$aux/copy/"
# Test-only injection, never an environment-controlled hook in delivered code.
cat > "$aux/hook" <<'HOOK'
sync_paths(){
    phase=$(cat "$work/state" 2>/dev/null || true)
    printf '%s|%s\n' "$phase" "$*" >> "$TEST_LOG"
    case "$TEST_MODE:$phase:$*" in
        prepare:PREPARING:*original.tsv*) return 1 ;;
        stage:APPLYING:*/.sasd-replace.*) return 1 ;;
        commit:COMMITTED:*/baseline.*) return 1 ;;
        rollback:ROLLING_BACK:*/etc)
            if [ "$(cat "$root/etc/hostname")" = old ]; then kill -KILL "$$"; fi ;;
    esac
    /usr/bin/sync -- "$@"
}
HOOK
awk -v hook="$aux/hook" '/^sync_paths\(\)\{/ {while ((getline line < hook)>0) print line; close(hook); next} {print}' "$here/lib/transaction.sh" > "$aux/copy/lib/transaction.sh"
printf 'dns1=192.0.2.53\nsearch=lab.invalid\n' > "$aux/site"
new_fixture(){
    [ -z "$root" ] || rm -rf -- "$root"
    root=$(mktemp -d /tmp/sasd-debian-lab.XXXXXXXX)
    mkdir "$root/etc"
    printf 'SASD-DEBIAN-FIXTURE-1\n' > "$root/.sasd-fixture"
    printf 'old\n' > "$root/etc/hostname"
    printf '127.0.0.1 localhost\n127.0.1.1 old.lab.invalid old\n::1 localhost\n' > "$root/etc/hosts"
    printf 'nameserver 192.0.2.99\nsearch old.invalid\n' > "$root/etc/resolv.conf"
    chmod 640 "$root/etc/hosts"
    hashes > "$aux/original"
    : > "$aux/sync.log"
}
hashes(){ (cd "$root/etc" && sha256sum hostname hosts resolv.conf && stat -c '%n %u:%g:%a' hostname hosts resolv.conf); }
run(){ TEST_MODE=$1 TEST_LOG="$aux/sync.log" "$aux/copy/apply-baseline.sh" --root="$root" --hostname=node.lab.invalid --site="$aux/site" --apply > "$aux/out" 2>&1; }
state(){ cat "$root"/baseline.*/state; }
reject(){ rc=0; run "$1" || rc=$?; [ "$rc" -ne 0 ]; ! grep -q '^FIXTURE ONLY;' "$aux/out"; }
# Normal ordering: snapshots before APPLYING, staged data before directory sync,
# and directory sync before the successful terminal journal.
new_fixture; run normal
[ "$(state)" = COMMITTED ]
awk -F '|' '
    $1=="PREPARING" && $2~/original.tsv/ && $2~/desired.tsv/ {a=NR}
    $1=="APPLYING" && $2~/\/.sasd-replace\./ && !b {b=NR}
    $1=="APPLYING" && b && $2~/\/etc$/ && !c {c=NR}
    $1=="COMMITTED" {d=NR}
    END {exit !(a && a<b && b<c && c<d)}' "$aux/sync.log"
# Pre-mutation sync failure leaves original files unchanged.
new_fixture; reject prepare; [ "$(state)" = PREPARING ]; hashes > "$aux/after"; cmp "$aux/original" "$aux/after"
# Staged-file sync failure is rolled back without changing target content.
new_fixture; reject stage; [ "$(state)" = ROLLED_BACK ]; hashes > "$aux/after"; cmp "$aux/original" "$aux/after"
# A terminal journal directory sync failure must not yield successful evidence.
new_fixture; reject commit; [ "$(state)" = SYNC_FAILED ]; grep -q 'JOURNAL SYNC UNCERTAIN' "$aux/out"
rc=0; "$here/apply-baseline.sh" --root="$root" --hostname=node.lab.invalid --site="$aux/site" --apply > "$aux/blocked" 2>&1 || rc=$?
[ "$rc" -eq 2 ]; grep -q 'ambiguous or invalid journal' "$aux/blocked"
# Simulate interrupted rollback after the first restored file, then use the real recovery tool.
new_fixture
cat > "$aux/copy/verify-baseline.sh" <<'VERIFY'
#!/bin/sh
case "$1" in */check) exit 0 ;; *) exit 1 ;; esac
VERIFY
chmod +x "$aux/copy/verify-baseline.sh"
rc=0; run rollback || rc=$?; [ "$rc" -eq 137 ]; [ "$(state)" = ROLLING_BACK ]
[ "$(cat "$root/etc/hostname")" = old ]; grep -q 'node.lab.invalid' "$root/etc/hosts"
for tx in "$root"/baseline.*; do :; done
"$here/recover-baseline.sh" --root="$root" --transaction="${tx##*/}" --apply
[ "$(state)" = ROLLED_BACK ]; hashes > "$aux/after"; cmp "$aux/original" "$aux/after"
echo 'Fixture durability ordering, sync failure and rollback interruption tests passed'
