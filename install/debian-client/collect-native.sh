#!/bin/sh
# Collect private, read-only lab evidence. No native write authorization.
set -eu
LC_ALL=C; export LC_ALL
umask 077
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
root=; live=no; host=; site=; inventory=; roles=; probe=; address_probe=
fail(){ echo "collect-native: $*" >&2; exit 2; }
for arg do
    case "$arg" in
        --live) [ "$live" = no ] || fail 'duplicate live'; live=yes ;;
        --root=*) [ -z "$root" ] || fail 'duplicate root'; root=${arg#*=} ;;
        --hostname=*) [ -z "$host" ] || fail 'duplicate hostname'; host=${arg#*=} ;;
        --site=*) [ -z "$site" ] || fail 'duplicate site'; site=${arg#*=} ;;
        --inventory=*) [ -z "$inventory" ] || fail 'duplicate inventory'; inventory=${arg#*=} ;;
        --roles=*) [ -z "$roles" ] || fail 'duplicate roles'; roles=${arg#*=} ;;
        --probe-name=*) [ -z "$probe" ] || fail 'duplicate probe'; probe=${arg#*=} ;;
        --probe-address=*) [ -z "$address_probe" ] || fail 'duplicate probe address'; address_probe=${arg#*=} ;;
        *) fail 'invalid argument; no apply' ;;
    esac
done
[ "$(id -u)" -ne 0 ] || fail 'run as ordinary user'
[ -n "$host" ] && [ -n "$site" ] && [ -n "$inventory" ] && [ -n "$roles" ] || fail 'hostname, site, inventory and roles required'
if [ "$live" = yes ]; then
    [ -z "$root" ] || fail 'choose live or fixture'; root=/; scope=LIVE_READ_ONLY
else
    case "$root" in /*) ;; *) fail 'absolute fixture required' ;; esac
    [ "$root" != / ] && [ -d "$root" ] && [ "$(realpath -e -- "$root")" = "$root" ] || fail 'unsafe fixture root'
    scope=FIXTURE_READ_ONLY
fi
for input in "$site" "$inventory" "$roles"; do
    [ -f "$input" ] && [ ! -L "$input" ] && [ -r "$input" ] || fail 'invalid input file'
done
. "$here/lib/policy.sh"
valid_hostname && render_resolver >/dev/null || fail 'invalid site or hostname'
if [ -n "$probe" ] || [ -n "$address_probe" ]; then
    [ "$live" = yes ] && [ -n "$probe" ] && [ -n "$address_probe" ] || fail 'paired probes require live mode'
    printf '%s\n' "$probe" | awk 'NR!=1 {bad=1} {n=split($0,a,"."); if(n<2 || length($0)>63) bad=1; for(i=1;i<=n;i++) if(length(a[i])>63 || a[i]!~/^[a-z0-9]([a-z0-9-]*[a-z0-9])?$/) bad=1} END{exit(bad || NR!=1)}' || fail 'invalid probe name'
    printf '%s\n' "$address_probe" | awk -F. 'NR!=1 || NF!=4 {bad=1} {for(i=1;i<=NF;i++) if($i!~/^(0|[1-9][0-9]*)$/ || $i>255) bad=1} END{exit(bad || NR!=1)}' || fail 'invalid probe address'
fi
report=$(mktemp -d /tmp/sasd-native-acceptance.XXXXXXXX)
printf 'Acceptance report: %s\n' "$report"
printf 'STARTED_NOT_AUTHORIZED\n' > "$report/status"
printf '%s\n' "$scope" > "$report/scope"
date -u +%FT%TZ > "$report/created-utc"
# Private copies freeze inputs for all child invocations. Never source them.
cp -- "$site" "$report/site.conf"
cp -- "$inventory" "$report/hosts.tsv"
cp -- "$roles" "$report/roles.tsv"
site=$report/site.conf; inventory=$report/hosts.tsv; roles=$report/roles.tsv
resolver=$(render_resolver) || fail 'copied DNS policy invalid'
(cd "$report" && sha256sum site.conf hosts.tsv roles.tsv > input.sha256)
printf 'check\texit\n' > "$report/commands.tsv"
run(){
    key=$1; shift; rc=0
    "$@" > "$report/$key.tsv" 2> "$report/$key.stderr" || rc=$?
    printf '%s\t%s\n' "$key" "$rc" >> "$report/commands.tsv"
}
run plan perl "$here/plan-client.pl" "--hostname=$host" "--inventory=$inventory" "--roles=$roles"
[ "$rc" -eq 0 ] || fail 'inventory plan rejected'
address=$(awk -F '\t' 'NR==1 && $0!="SASD-CLIENT-PLAN-1" {bad=1} NR==2 && $1=="host" && NF==7 {print $3; ok=1} END{exit(bad || !ok)}' "$report/plan.tsv") || fail 'invalid plan'
[ -n "$address" ] || fail 'missing plan address'
if [ "$live" = yes ]; then set -- --live; else set -- "--root=$root"; fi
if [ -n "$probe" ]; then
    run preflight perl "$here/native-preflight.pl" "$@" "--hostname=$host" "--address=$address" "--probe-name=$probe" "--probe-address=$address_probe"
else
    run preflight perl "$here/native-preflight.pl" "$@" "--hostname=$host" "--address=$address"
fi
preflight_rc=$rc
run capabilities /usr/bin/python3 "$here/native-capabilities.py" "$@"
cap_rc=$rc
run baseline sh "$here/verify-baseline.sh" "--root=$root" "--hostname=$host" "--site=$site"
baseline_rc=$rc
# Rehearse on copies; preserve the private child report within the collection.
if [ "$live" = yes ]; then set -- --live; else set -- "--source-root=$root"; fi
run rehearsal sh "$here/prepare-native.sh" "$@" "--hostname=$host" "--site=$site" "--inventory=$inventory" "--roles=$roles"
rehearsal_rc=$rc
child=$(sed -n 's/^Native review: //p' "$report/rehearsal.tsv")
if [ -n "$child" ]; then
    case "$child" in /tmp/sasd-native-review.*) suffix=${child#/tmp/sasd-native-review.} ;; *) fail 'unexpected review path' ;; esac
    case "$suffix" in ''|*[!a-zA-Z0-9]*) fail 'unexpected review token' ;; esac
    [ -d "$child" ] && [ ! -L "$child" ] && [ "$(stat -c '%u:%a' -- "$child")" = "$(id -u):700" ] || fail 'unsafe review directory'
    mv -T -- "$child" "$report/rehearsal"
fi
if [ "$rehearsal_rc" -eq 0 ]; then
    [ -f "$report/rehearsal/status" ] && [ "$(cat "$report/rehearsal/status")" = PREPARED_NOT_AUTHORIZED ] && cmp -s "$report/plan.tsv" "$report/rehearsal/plan.tsv" || fail 'review evidence inconsistent'
fi
# DNS requires explicit opt-in and uses only the frozen site policy servers.
dns_status=NOT_RUN
if [ -n "$probe" ]; then
    dns_status=OBSERVED
    for server in $(printf '%s\n' "$resolver" | awk '$1=="nameserver" && !seen[$2]++ {print $2}'); do
        run "dns-$server" perl "$here/verify-dns.pl" --live "--server=$server" "--name=$probe" "--expected=$address_probe"
        if [ "$rc" -ne 0 ] || ! grep -qx 'scope[[:space:]]LIVE_DNS' "$report/dns-$server.tsv" || ! grep -qx 'status[[:space:]]MATCH' "$report/dns-$server.tsv"; then dns_status=BLOCKED; fi
    done
    if [ "$preflight_rc" -ne 0 ] || ! grep -q '^nss-probe[[:space:]]MATCH[[:space:]]' "$report/preflight.tsv"; then dns_status=BLOCKED; fi
fi
# Reports are observations, never automatic approvals. Drift before apply is expected.
g2=REVIEW_REQUIRED
if [ "$preflight_rc" -ne 0 ] || [ "$cap_rc" -ne 0 ] || [ "$rehearsal_rc" -ne 0 ]; then g2=BLOCKED; fi
printf 'gate\tstatus\treason\n' > "$report/gates.tsv"
printf 'G0\tOPEN\trepository-suite-and-release-trust\nG1\tOPEN\toperator-console-isolation-snapshot\nG2\t%s\tdiagnostics-and-resolver-ownership-review\nG3\tOPEN\texperimental-writer-not-authorized\nG4\tNOT_RUN\tno-native-apply\nG5\t%s\tNSS-and-direct-DNS-observations-only\nG6\tNOT_RUN\tno-native-recovery-or-reboot\n' "$g2" "$dns_status" >> "$report/gates.tsv"
printf 'baseline-exit\t%s\n' "$baseline_rc" > "$report/observations.tsv"
printf 'COLLECTED_NOT_AUTHORIZED\n' > "$report/status.new"
mv -fT -- "$report/status.new" "$report/status"
cat "$report/gates.tsv"
echo 'Private evidence collected; no native write authorization.'
exit 3
