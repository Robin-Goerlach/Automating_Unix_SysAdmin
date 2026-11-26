#!/bin/sh
# Prepare a native baseline review from read-only source files, never apply to them.
set -eu
LC_ALL=C; export LC_ALL
umask 077
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
source_root=; live=no; host=; site=; inventory=; roles=
fail(){ echo "prepare-native: $*" >&2; exit 2; }
for arg do
    case "$arg" in
        --live) [ "$live" = no ] || fail 'duplicate live'; live=yes ;;
        --source-root=*) [ -z "$source_root" ] || fail 'duplicate source'; source_root=${arg#*=} ;;
        --hostname=*) [ -z "$host" ] || fail 'duplicate hostname'; host=${arg#*=} ;;
        --site=*) [ -z "$site" ] || fail 'duplicate site'; site=${arg#*=} ;;
        --inventory=*) [ -z "$inventory" ] || fail 'duplicate inventory'; inventory=${arg#*=} ;;
        --roles=*) [ -z "$roles" ] || fail 'duplicate roles'; roles=${arg#*=} ;;
        *) fail 'invalid argument; no native apply' ;;
    esac
done
uid=$(id -u); [ "$uid" -ne 0 ] || fail 'run as ordinary user'
[ -n "$host" ] && [ -n "$site" ] && [ -n "$inventory" ] && [ -n "$roles" ] || fail 'hostname, site, inventory and roles required'
if [ "$live" = yes ]; then
    [ -z "$source_root" ] || fail 'choose live or fixture source'
    source_root=/; owner=0; scope=LIVE_READ_ONLY
else
    case "$source_root" in /*) ;; *) fail 'absolute fixture source required' ;; esac
    [ -d "$source_root" ] && [ ! -L "$source_root" ] || fail 'invalid fixture source'
    source_root=$(realpath -e -- "$source_root") || fail 'cannot resolve source'
    [ "$source_root" != / ] || fail 'real root requires live'
    owner=$uid; scope=FIXTURE_SOURCE
fi
etc=${source_root%/}/etc
[ -d "$etc" ] && [ ! -L "$etc" ] || fail 'unsafe etc directory'
. "$here/lib/policy.sh"
valid_hostname && render_resolver >/dev/null || fail 'invalid site or hostname'
plan=$(perl "$here/plan-client.pl" "--hostname=$host" "--inventory=$inventory" "--roles=$roles") || fail 'inventory or plan rejected'
address=$(printf '%s\n' "$plan" | awk -F '\t' 'NR==2 && $1=="host" && NF==7 {print $3}')
[ -n "$address" ] || fail 'invalid inventory plan'
# Source trees and input files must be trusted and stable; this is not a sandbox.
# Reject unsafe final links, multiple links, unexpected owner and writable group/other.
source_manifest(){
    for name in hostname hosts resolv.conf; do
        f=$etc/$name
        [ -f "$f" ] && [ ! -L "$f" ] && [ -r "$f" ] || return 1
        meta=$(stat -c '%u:%g:%a:%h:%s' -- "$f") || return 1
        printf '%s\n' "$meta" | awk -F: -v uid="$owner" '$1==uid && $4==1 && $5<=65536 && $3~/^[0-7][0145][0145]$/ {ok=1} END{exit !ok}' || return 1
        hash=$(sha256sum < "$f") || return 1
        printf '%s\t%s\t%s\n' "$name" "$meta" "${hash%% *}"
    done
}
before=$(source_manifest) || fail 'unsafe source files; managed resolver or unsupported metadata'
report=$(mktemp -d /tmp/sasd-native-review.XXXXXXXX)
printf 'Native review: %s\n' "$report"
printf 'STARTED_NOT_AUTHORIZED\n' > "$report/status"
fixture=; child_report=
cleanup(){
    [ -z "$fixture" ] || rm -rf -- "$fixture"
    [ -z "$child_report" ] || rm -rf -- "$child_report"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM
printf '%s\n' "$scope" > "$report/scope"
printf '%s\n' "$source_root" > "$report/source-root"
date -u +%FT%TZ > "$report/created-utc"
printf '%s\n' "$plan" > "$report/plan.tsv"
printf '%s\n' "$before" > "$report/source.tsv"
cp -- "$site" "$report/site.conf"
site=$report/site.conf
render_resolver >/dev/null || fail 'invalid copied policy'
if [ "$live" = yes ]; then set -- --live; else set -- "--root=$source_root"; fi
perl "$here/native-preflight.pl" "$@" "--hostname=$host" "--address=$address" > "$report/preflight.tsv"
# Static-only candidate review is permitted, not proof of resolver ownership.
awk -F '\t' '$1=="os" && $2=="DETECTED" && ($3=="debian:12" || $3=="debian:13") {a++} $1=="resolver-owner-hint" && $2=="UNKNOWN_REGULAR" {b++} END{exit !(a==1 && b==1)}' "$report/preflight.tsv" || fail 'OS or resolver outside static review scope'
fixture=$(mktemp -d /tmp/sasd-debian-lab.XXXXXXXX)
mkdir "$fixture/etc" "$report/original" "$report/desired"
printf 'SASD-DEBIAN-FIXTURE-1\n' > "$fixture/.sasd-fixture"
for name in hostname hosts resolv.conf; do
    cp --preserve=mode -- "$etc/$name" "$report/original/$name"
    cp --preserve=mode -- "$report/original/$name" "$fixture/etc/$name"
done
[ "$(source_manifest)" = "$before" ] || fail 'source changed during capture'
# Compare actual captured bytes to the original source manifest.
for name in hostname hosts resolv.conf; do
    hash=$(sha256sum < "$report/original/$name")
    expected=$(printf '%s\n' "$before" | awk -F '\t' -v name="$name" '$1==name {print $3}')
    [ "${hash%% *}" = "$expected" ] || fail 'captured bytes differ'
done
rc=0
sh "$here/dispatch-fixture.sh" --fixture-apply "--root=$fixture" "--hostname=$host" "--site=$site" "--inventory=$inventory" "--roles=$roles" > "$report/rehearsal.log" 2>&1 || rc=$?
child=$(sed -n 's/^Fixture report: //p' "$report/rehearsal.log")
case "$child" in /tmp/sasd-debian-fixture-report.*) suffix=${child#/tmp/sasd-debian-fixture-report.}; case "$suffix" in ''|*[!a-zA-Z0-9]*) fail 'invalid rehearsal report' ;; esac; child_report=$child ;; esac
[ "$rc" -eq 0 ] && [ -n "$child_report" ] || fail 'fixture rehearsal failed'
[ "$(cat "$child_report/status")" = VERIFIED_FIXTURE ] || fail 'fixture not verified'
cmp -s "$report/plan.tsv" "$child_report/plan.tsv" || fail 'inventory changed during rehearsal'
for name in hostname hosts resolv.conf; do
    cp --preserve=mode -- "$fixture/etc/$name" "$report/desired/$name"
done
cp -- "$child_report/manifest.tsv" "$report/desired.tsv"
cp -- "$child_report/verify.tsv" "$report/rehearsal-verify.tsv"
[ "$(source_manifest)" = "$before" ] || fail 'source changed during rehearsal'
printf 'file\tchange\n' > "$report/changes.tsv"
for name in hostname hosts resolv.conf; do
    if cmp -s "$report/original/$name" "$report/desired/$name"; then change=UNCHANGED; else change=PROPOSED; fi
    printf '%s\t%s\n' "$name" "$change" >> "$report/changes.tsv"
done
printf 'PREPARED_NOT_AUTHORIZED\n' > "$report/status.new"
mv -fT -- "$report/status.new" "$report/status"
cat "$report/changes.tsv"
echo 'Review only. Resolver ownership and native write authorization remain open.'
