#!/bin/sh
# Fixture-only static configuration transaction. No live system operation.
set -eu
LC_ALL=C; export LC_ALL
umask 077
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
. "$here/lib/policy.sh"
. "$here/lib/transaction.sh"
root=; host=; site=; mode=dry; expect_original=; expect_desired=
fail(){ echo "baseline: $*" >&2; exit 2; }
for arg do
    case "$arg" in
        --root=*) root=${arg#*=} ;;
        --hostname=*) host=${arg#*=} ;;
        --site=*) site=${arg#*=} ;;
        --dryrun|--dry-run) mode=dry ;;
        --apply) mode=apply ;;
        --expect-original=*) [ -z "$expect_original" ] || fail "duplicate original digest"; expect_original=${arg#*=} ;;
        --expect-desired=*) [ -z "$expect_desired" ] || fail "duplicate desired digest"; expect_desired=${arg#*=} ;;
        *) fail 'unknown argument' ;;
    esac
done
fixture_check || fail 'invalid fixture or root execution'
if [ -n "$expect_original" ] || [ -n "$expect_desired" ]; then
    [ "$mode" = apply ] && [ "$layout" = SASD-DEBIAN-FIXTURE-2 ] || fail 'reference requires V2 apply'
    for digest in "$expect_original" "$expect_desired"; do
        printf '%s\n' "$digest" | grep -Eq '^[0-9a-f]{64}$' || fail 'invalid reference digest'
    done
fi
valid_hostname || fail 'invalid hostname'
expected=$(render_resolver) || fail 'invalid DNS policy'
# The kernel releases this lock on process exit; no PID guessing is required.
exec 9< "$root"
flock -n -x 9 || fail 'fixture busy'
fixture_check || fail 'fixture or journal layout changed'
[ ! -e "$root/.baseline-lock" ] && [ ! -L "$root/.baseline-lock" ] || fail 'legacy lock requires review'
pending=$(pending_transaction) || fail 'ambiguous or invalid journal'
[ -z "$pending" ] || fail "recovery required: $pending"
work=
cleanup(){
    rc=$?; trap - EXIT; trap '' HUP INT TERM
    if [ -n "$work" ]; then
        state=$(state_get "$work" || true)
        case "$state" in
            APPLYING|ROLLING_BACK) restore_transaction || { echo "ROLLBACK INCOMPLETE: $work" >&2; rc=1; } ;;
        esac
    fi
    exit "$rc"
}
if [ "$mode" = apply ]; then
    trap cleanup EXIT; trap 'exit 1' HUP INT TERM
fi
metadata_manifest "$root/etc" >/dev/null || fail "unsafe or unsupported target metadata"
. "$here/lib/baseline-render.sh"
render_baseline
if [ "$mode" = dry ]; then
    printf 'PLANNED hostname=%s\nPLANNED hosts (preserve unrelated lines)\nPLANNED static resolver (preserve non-policy lines)\n' "$host"
    exit 0
fi
work=$(mktemp -d "$journal_parent/baseline.XXXXXXXX")
state_set PREPARING
mkdir "$work/original" "$work/check" "$work/check/etc"
for name in hostname hosts resolv.conf; do
    cp -p -- "$root/etc/$name" "$work/original/$name"
    cp -p -- "$root/etc/$name" "$work/check/etc/$name"
    same_file "$root/etc/$name" "$work/original/$name" && same_file "$root/etc/$name" "$work/check/etc/$name" || fail "snapshot mismatch: $name"
done
printf '%s\n' "$short" > "$work/check/etc/hostname"
printf '%s\n' "$hosts" > "$work/check/etc/hosts"
printf '%s\n' "$resolver" > "$work/check/etc/resolv.conf"
"$here/verify-baseline.sh" --root="$work/check" --hostname="$host" --site="$site"
manifest "$work/original" > "$work/original.tsv"
manifest "$work/check/etc" > "$work/desired.tsv"
record_metadata || fail "cannot record metadata"
verify_target_metadata original || fail "source changed before apply"
if [ -n "$expect_original" ]; then
    actual=$(sha256sum < "$work/original-metadata.tsv")
    [ "${actual%% *}" = "$expect_original" ] || fail 'reference original mismatch'
    actual=$(sha256sum < "$work/desired-metadata.tsv")
    [ "${actual%% *}" = "$expect_desired" ] || fail 'reference desired mismatch'
fi
# All recovery evidence precedes the first mutation; snapshots remain in place.
sync_prepared || fail 'cannot synchronize recovery evidence'
state_set APPLYING
for name in hostname hosts resolv.conf; do
    if same_file "$work/check/etc/$name" "$root/etc/$name"; then
        printf 'UNCHANGED %s\n' "$name"
    else
        replace_file "$work/check/etc/$name" "$root/etc/$name"
        printf 'CHANGED %s\n' "$name"
    fi
done
"$here/verify-baseline.sh" --root="$root" --hostname="$host" --site="$site"
actual=$(manifest "$root/etc")
[ "$actual" = "$(cat "$work/desired.tsv")" ] || fail 'installed manifest mismatch'
verify_target_metadata desired || fail "installed metadata mismatch"
sync_targets || fail 'cannot synchronize installed files'
state_set COMMITTED
printf 'FIXTURE ONLY; backup=%s/original\n' "$work"
