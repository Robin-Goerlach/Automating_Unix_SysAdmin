#!/bin/sh
# Explicit recovery for one interrupted fixture transaction. No live writes.
set -eu
LC_ALL=C; export LC_ALL
umask 077
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
. "$here/lib/transaction.sh"
root=; transaction=; mode=dry
fail(){ echo "recovery: $*" >&2; exit 2; }
for arg do
    case "$arg" in
        --root=*) root=${arg#*=} ;;
        --transaction=*) transaction=${arg#*=} ;;
        --dryrun|--dry-run) mode=dry ;;
        --apply) mode=apply ;;
        *) fail 'unknown argument' ;;
    esac
done
fixture_check || fail 'invalid fixture'
case "$transaction" in baseline.*) ;; *) fail 'invalid transaction' ;; esac
suffix=${transaction#baseline.}
case "$suffix" in ''|*[!a-zA-Z0-9]*) fail 'invalid transaction name' ;; esac
exec 9< "$root"
flock -n -x 9 || fail 'fixture busy'
fixture_check || fail 'fixture or journal layout changed'
[ ! -e "$root/.baseline-lock" ] && [ ! -L "$root/.baseline-lock" ] || fail 'legacy lock requires review'
work=$journal_parent/$transaction
pending=$(pending_transaction) || fail 'ambiguous or invalid journal'
[ "$pending" = "$work" ] || fail 'transaction not the sole open transaction'
restore_preflight || fail 'backup or target conflict; no files changed'
if [ "$mode" = dry ]; then
    printf 'RECOVERY PLANNED %s\n' "$transaction"
    exit 0
fi
restore_transaction || { echo 'Recovery incomplete; keep backups and retry after review' >&2; exit 1; }
printf 'RECOVERY COMPLETE %s\n' "$transaction"
