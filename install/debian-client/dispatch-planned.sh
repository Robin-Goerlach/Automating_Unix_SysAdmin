#!/bin/sh
# Inventory-bound candidate execution; never applies configuration.
set -eu
LC_ALL=C; export LC_ALL
umask 077
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
mode=--dryrun; host=; site=; inventory=; roles=; only=; list=no
fail(){ echo "planned dispatch: $*" >&2; exit 2; }
for arg do
    case "$arg" in
        --hostname=*) [ -z "$host" ] || fail 'duplicate hostname'; host=${arg#*=} ;;
        --site=*) [ -z "$site" ] || fail 'duplicate site'; site=${arg#*=} ;;
        --inventory=*) [ -z "$inventory" ] || fail 'duplicate inventory'; inventory=${arg#*=} ;;
        --roles=*) [ -z "$roles" ] || fail 'duplicate roles'; roles=${arg#*=} ;;
        --only=*) [ -z "$only" ] || fail 'duplicate only'; only=${arg#*=} ;;
        --dryrun|--dry-run) mode=--dryrun ;;
        --stage) mode=--render ;;
        --list) list=yes ;;
        *) fail 'invalid argument (no apply or external evidence supported)' ;;
    esac
done
[ -n "$host" ] && [ -n "$inventory" ] && [ -n "$roles" ] || fail 'hostname, inventory and roles required'
[ "$mode" != --render ] || [ "$(id -u)" -ne 0 ] || fail 'stage must run unprivileged'
set -- "--hostname=$host" "--inventory=$inventory" "--roles=$roles"
[ -z "$only" ] || set -- "$@" "--only=$only"
plan=$(perl "$here/plan-client.pl" "$@") || fail 'inventory or plan rejected'
[ "$(printf '%s\n' "$plan" | sed -n '1p')" = SASD-CLIENT-PLAN-1 ] || fail 'unsupported plan version'
if [ "$list" = yes ]; then printf '%s\n' "$plan"; exit 0; fi
# No externally supplied plan or evidence. Only this run can satisfy candidate edges.
rows=$(printf '%s\n' "$plan" | tail -n +4)
[ -n "$rows" ] || fail 'empty plan'
stage=; successful=' '; pending=0; failed=0; planned=0; staged=0; notrun=0
if [ "$mode" = --render ]; then
    stage=$(mktemp -d /tmp/sasd-debian-stage.XXXXXXXX)
    printf '%s\n' "$plan" > "$stage/plan.tsv"
    printf 'id\ttask\tstatus\tsha256\n' > "$stage/results.tsv"
fi
printf 'SASD Debian postinstall checklist (inventory-bound)\nNode: %s\nMode: %s\n' "$host" "$mode"
[ -z "$stage" ] || printf 'Candidate directory: %s\n' "$stage"
record(){
    printf '[ ] %-16s %s_%s\n' "$1" "$id" "$name"
    if [ -n "$stage" ]; then printf '%s\t%s\t%s\t%s\n' "$id" "$name" "$1" "$2" >> "$stage/results.tsv"; fi
}
tab=$(printf '\t')
while IFS="$tab" read -r id name category status deps; do
    [ -n "$id" ] || continue
    if [ "$failed" -ne 0 ]; then record NOT_RUN -; notrun=$((notrun+1)); continue; fi
    block=
    # Verified evidence is never accepted in dryrun/stage. A planned candidate
    # must also have actually succeeded in the current mode before dependants run.
    if [ "$deps" != - ]; then
        for edge in $(printf '%s' "$deps" | tr ',' ' '); do
            prerequisite=${edge%:*}; kind=${edge#*:}
            case "$kind" in
                verified) block=WAIT_VERIFIED; break ;;
                candidate) case "$successful" in *" $prerequisite "*) ;; *) block=WAIT_CANDIDATE ;; esac ;;
                *) fail 'invalid plan evidence' ;;
            esac
        done
    fi
    if [ -n "$block" ]; then record "$block" -; pending=$((pending+1)); continue; fi
    if [ "$category" != render ]; then
        case "$category" in deferred|manual|central|review) record "$(printf '%s' "$category" | tr 'a-z' 'A-Z')" -; pending=$((pending+1)); continue ;; *) fail 'invalid plan category' ;; esac
    fi
    rc=0; digest=-
    if [ "$mode" = --render ]; then
        candidate="$stage/${id}_$name.candidate"
        (set -C; sh "$here/tasks/${id}_$name" "$mode" "--hostname=$host" "--site=$site" > "$candidate") || rc=$?
        if [ "$rc" -eq 0 ]; then
            digest=$(sha256sum < "$candidate"); digest=${digest%% *}
            record STAGED "$digest"; staged=$((staged+1)); successful="$successful$id "; continue
        fi
        rm -f -- "$candidate"
    else
        sh "$here/tasks/${id}_$name" "$mode" "--hostname=$host" "--site=$site" >/dev/null || rc=$?
        if [ "$rc" -eq 10 ]; then record PLANNED -; planned=$((planned+1)); successful="$successful$id "; continue; fi
    fi
    if [ "$rc" -eq 20 ]; then record DEFERRED -; pending=$((pending+1)); else record FAILED -; failed=1; fi
done <<ROWS
$rows
ROWS
printf 'Summary: planned=%s staged=%s pending=%s failed=%s not-run=%s\n' "$planned" "$staged" "$pending" "$failed" "$notrun"
echo 'No live changes; candidates are not installed-state evidence.'
[ "$failed" -eq 0 ] || exit 1
[ "$pending" -eq 0 ] || exit 3
