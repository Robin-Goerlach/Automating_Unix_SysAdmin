#!/bin/sh
# Fixture-only static configuration transaction. No live system operation.
set -eu
LC_ALL=C; export LC_ALL
umask 077
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
. "$here/lib/policy.sh"
. "$here/lib/transaction.sh"
root=; host=; site=; mode=dry
fail(){ echo "baseline: $*" >&2; exit 2; }
for arg do
    case "$arg" in
        --root=*) root=${arg#*=} ;;
        --hostname=*) host=${arg#*=} ;;
        --site=*) site=${arg#*=} ;;
        --dryrun|--dry-run) mode=dry ;;
        --apply) mode=apply ;;
        *) fail 'unknown argument' ;;
    esac
done
fixture_check || fail 'invalid fixture or root execution'
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
old=$(cat "$root/etc/hostname"); short=${host%%.*}
printf '%s\n' "$old" | awk 'NR!=1 || length($0)>63 || $0!~/^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$/ {bad=1} END{exit(bad || NR!=1)}' || fail 'old hostname must be a short name'
# Preserve unrelated entries, IPv6 and comments. Reject ambiguous local mapping.
hosts=$(awk -v old="$old" -v fqdn="$host" -v short="$short" '
    {original=$0; comment=""; if(match($0,/#/)) {comment=substr($0,RSTART); $0=substr($0,1,RSTART-1)}
     if($1=="127.0.0.1") for(i=2;i<=NF;i++) if($i=="localhost") local_ok=1
     if($1=="127.0.1.1") {if(++count>1 || NF<2 || NF>3) bad=1; if(NF==2 && $2!=old && $2!=short) bad=1; if(NF==3 && !(($3==old && index($2,old ".")==1) || ($3==short && $2==fqdn))) bad=1; print "127.0.1.1 " fqdn " " short (comment!="" ? " " comment : ""); next}
     for(i=2;i<=NF;i++) if($i==fqdn || $i==short) bad=1; print original}
    END{if(!local_ok || bad) exit 1; if(!count) print "127.0.1.1 " fqdn " " short}
' "$root/etc/hosts") || fail 'ambiguous hosts mapping or missing localhost'
resolver=$(awk '$1!~/^(nameserver|search|domain)$/ {print}' "$root/etc/resolv.conf") || fail 'resolver read failed'
if [ -n "$resolver" ]; then resolver=$(printf '%s\n%s' "$resolver" "$expected"); else resolver=$expected; fi
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
