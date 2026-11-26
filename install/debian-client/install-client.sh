#!/bin/sh
# Dispatcher: lexical file order, not a hard-coded list. No privileged apply.
set -eu
LC_ALL=C; export LC_ALL
umask 077
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
# New explicit group route and read-only coverage, before legacy fixture routing.
for arg do
    case "$arg" in --orchestration-plan) exec /usr/bin/python3 -I "$here/orchestration-plan.py" "$@" ;; esac
done
for arg do
    case "$arg" in --evidence-report) exec /usr/bin/python3 -I "$here/fixture-evidence.py" "$@" ;; esac
done
for arg do
    case "$arg" in --coverage|--fixture-group=*) exec /usr/bin/python3 -I "$here/fixture-dispatch.py" "$@" ;; esac
done
# Route explicit fixture operation before the inventory candidate path, regardless of option order.
for arg do
    case "$arg" in --fixture-apply) exec sh "$here/dispatch-fixture.sh" "$@" ;; esac
done
# Inventory arguments opt into dependency-aware execution; legacy dryrun stays available.
for arg do
    case "$arg" in --inventory=*|--roles=*) exec sh "$here/dispatch-planned.sh" "$@" ;; esac
done
mode=--dryrun; host=; site=; only=; stage=; list=no
usage(){ echo 'usage: install-client.sh --hostname=FQDN [--site=FILE] [--dryrun|--stage] [--only=NNNN] [--inventory=FILE --roles=FILE] | --list | --fixture-apply --root=FIXTURE --hostname=FQDN --site=FILE --inventory=FILE --roles=FILE' >&2; exit 2; }
while [ "$#" -gt 0 ]; do
    case "$1" in
        --dryrun|--dry-run) mode=--dryrun ;;
        --stage) mode=--render ;;
        --hostname=*) host=${1#*=} ;;
        --site=*) site=${1#*=} ;;
        --only=*) only=${1#*=}; printf '%s\n' "$only" | grep -Eq '^[0-9]{4}$' || usage ;;
        --list) list=yes ;;
        *) usage ;;
    esac
    shift
done
[ "$list" = yes ] || [ -n "$host" ] || usage
# Preflight filenames and unique numeric prefixes before executing any task.
prev=; count=0
for f in "$here"/tasks/*; do
    [ -f "$f" ] && [ ! -L "$f" ] || usage
    name=${f##*/}; id=${name%%_*}
    printf '%s\n' "$name" | grep -Eq '^[0-9]{4}_[A-Za-z0-9_]+$' || usage
    [ "$prev" != "$id" ] || { echo 'Duplicate task number' >&2; exit 2; }
    prev=$id
    if [ -z "$only" ] || [ "$only" = "$id" ]; then count=$((count+1)); fi
done
[ "$count" -gt 0 ] || usage
if [ "$list" = yes ]; then
    for f in "$here"/tasks/*; do name=${f##*/}; [ -z "$only" ] || [ "$only" = "${name%%_*}" ] || continue; printf '%s\n' "$name"; done
    exit 0
fi
[ -f "$here/lib/task.sh" ] && [ ! -L "$here/lib/task.sh" ] || usage
. "$here/lib/task.sh"
valid_hostname || { echo "Invalid hostname" >&2; exit 2; }
if [ "$mode" = --render ]; then
    [ "$(id -u)" -ne 0 ] || { echo 'Stage must run unprivileged' >&2; exit 2; }
    stage=$(mktemp -d /tmp/sasd-debian-stage.XXXXXXXX)
fi
printf 'SASD Debian postinstall checklist\nNode: %s\nDate: %s\nMode: %s\n' "$host" "$(date -u +%FT%TZ)" "$mode"
[ -z "$stage" ] || printf 'Candidate directory: %s\n' "$stage"
planned=0; rendered=0; pending=0; failed=0; notrun=0
for f in "$here"/tasks/*; do
    name=${f##*/}; id=${name%%_*}
    [ -z "$only" ] || [ "$id" = "$only" ] || continue
    if [ "$failed" -gt 0 ]; then
        printf '[ ] NOT RUN   %s\n' "$name"; notrun=$((notrun+1)); continue
    fi
    rc=0
    output=$(sh "$f" "$mode" "--hostname=$host" "--site=$site") || rc=$?
    case "$rc" in
        0) if [ "$mode" != --render ] || ! (set -C; printf '%s\n' "$output" > "$stage/$name.candidate"); then
               printf '[!] FAILED    %s\n' "$name"; failed=1
           else printf '[~] STAGED    %s\n' "$name"; rendered=$((rendered+1)); fi ;;
        10) printf '[ ] PLANNED   %s -- %s\n' "$name" "$output"; planned=$((planned+1)) ;;
        20) printf '[ ] DEFERRED  %s -- %s\n' "$name" "$output"; pending=$((pending+1)) ;;
        21) printf '[ ] MANUAL    %s -- %s\n' "$name" "$output"; pending=$((pending+1)) ;;
        22) printf '[ ] CENTRAL   %s -- %s\n' "$name" "$output"; pending=$((pending+1)) ;;
        23) printf '[ ] REVIEW    %s -- %s\n' "$name" "$output"; pending=$((pending+1)) ;;
        *) printf '[!] FAILED    %s (exit %s)\n' "$name" "$rc"; failed=1 ;;
    esac
done
printf 'Summary: planned=%s staged=%s pending=%s failed=%s not-run=%s\n' "$planned" "$rendered" "$pending" "$failed" "$notrun"
echo 'No live host changes; no task is certified installed.'
[ "$failed" -eq 0 ] || exit 1
[ "$pending" -eq 0 ] || exit 3
