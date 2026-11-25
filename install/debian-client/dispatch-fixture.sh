#!/bin/sh
# Bounded inventory-bound baseline fixture transaction; never a live apply.
set -eu
LC_ALL=C; export LC_ALL
umask 077
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
. "$here/lib/transaction.sh"
. "$here/lib/policy.sh"
root=; host=; site=; inventory=; roles=; enabled=no
fail(){ echo "fixture dispatch: $*" >&2; exit 2; }
for arg do
    case "$arg" in
        --fixture-apply) [ "$enabled" = no ] || fail 'duplicate mode'; enabled=yes ;;
        --root=*) [ -z "$root" ] || fail 'duplicate root'; root=${arg#*=} ;;
        --hostname=*) [ -z "$host" ] || fail 'duplicate hostname'; host=${arg#*=} ;;
        --site=*) [ -z "$site" ] || fail 'duplicate site'; site=${arg#*=} ;;
        --inventory=*) [ -z "$inventory" ] || fail 'duplicate inventory'; inventory=${arg#*=} ;;
        --roles=*) [ -z "$roles" ] || fail 'duplicate roles'; roles=${arg#*=} ;;
        *) fail 'invalid argument; fixture baseline is an indivisible operation' ;;
    esac
done
[ "$enabled" = yes ] && [ -n "$host" ] && [ -n "$inventory" ] && [ -n "$roles" ] || fail 'explicit mode, hostname, inventory and roles required'
fixture_check || fail 'invalid fixture or root execution'
valid_hostname || fail 'invalid hostname'
render_resolver >/dev/null || fail 'invalid site policy'
plan=$(perl "$here/plan-client.pl" "--hostname=$host" "--inventory=$inventory" "--roles=$roles") || fail 'inventory or plan rejected'
# Allow only the reviewed baseline group and its known prerequisite contract.
# A future catalog/dependency change must not silently broaden this operation.
printf '%s\n' "$plan" | awk -F '\t' '
    NR==1 {if($0!="SASD-CLIENT-PLAN-1") bad=1}
    NR==2 {if($1!="host" || NF!=7) bad=1}
    $1=="0010" {a++; if($2!="DNS_Client_Set_Name_Server" || $3!="render" || $4!="PLAN_CANDIDATE" || $5!="-") bad=1}
    $1=="0030" {b++; if($2!="Host_Set_Name" || $3!="render" || $4!="PLAN_CANDIDATE" || $5!="-") bad=1}
    $1=="0040" {c++; if($2!="Host_Configure_FQDN" || $3!="render" || $4!="PLAN_CANDIDATE" || $5!="0030:candidate") bad=1}
    END {exit(bad || a!=1 || b!=1 || c!=1)}' || fail 'baseline dependency contract changed'
report=$(mktemp -d /tmp/sasd-debian-fixture-report.XXXXXXXX)
printf 'Fixture report: %s\n' "$report"
printf 'STARTED\n' > "$report/status"
printf '%s\n' "$plan" > "$report/plan.tsv"
# Freeze validated DNS input for apply and post-apply evidence.
cp -- "$site" "$report/site.conf"
site=$report/site.conf
render_resolver >/dev/null || fail 'invalid copied site policy'
# The child owns the transaction lock; it releases it after commit.
if ! sh "$here/apply-baseline.sh" "--root=$root" "--hostname=$host" "--site=$site" --apply > "$report/apply.log" 2>&1; then
    printf 'APPLY_FAILED_OR_INTERRUPTED\n' > "$report/status"
    echo 'Fixture apply failed; inspect transaction journal and apply.log' >&2
    exit 1
fi
# Bind evidence to the particular transaction reported by this invocation.
backup=$(sed -n 's/^FIXTURE ONLY; backup=//p' "$report/apply.log")
case "$backup" in "$root"/baseline.*/original) ;; *) echo 'Missing transaction reference' >&2; exit 1 ;; esac
work=${backup%/original}; token=${work##*/baseline.}
case "$token" in ''|*[!a-zA-Z0-9]*) echo 'Invalid transaction reference' >&2; exit 1 ;; esac
[ "$work" = "$root/baseline.$token" ] || exit 1
# Lock again and reject any changed or open transaction before recording evidence.
exec 9< "$root"
flock -n -x 9 || { echo 'Evidence lock busy' >&2; exit 1; }
fixture_check && private_dir "$work" && [ "$(state_get "$work")" = COMMITTED ] && snapshot_valid || exit 1
pending=$(pending_transaction) || exit 1
[ -z "$pending" ] || exit 1
actual=$(manifest "$root/etc") || exit 1
[ "$actual" = "$(cat "$work/desired.tsv")" ] || { echo 'Fixture changed since commit' >&2; exit 1; }
verify_target_metadata desired || { echo "Fixture metadata changed since commit" >&2; exit 1; }
cp -- "$work/desired-metadata.tsv" "$report/metadata.tsv"
sh "$here/verify-baseline.sh" "--root=$root" "--hostname=$host" "--site=$site" > "$report/verify.tsv" || exit 1
printf '%s\n' "$actual" > "$report/manifest.tsv"
printf '%s\n' "$work" > "$report/transaction"
printf '%s\n' "$root" > "$report/fixture-root"
# Result is scoped to static fixture files; never runtime or native evidence.
awk -F '\t' 'BEGIN{OFS="\t"; print "id","task","status","file","sha256"}
    $1=="resolv.conf" {r=$3} $1=="hostname" {h=$3} $1=="hosts" {s=$3}
    END{if(!r || !h || !s) exit 1;
    print "0010","DNS_Client_Set_Name_Server","FIXTURE_VERIFIED","resolv.conf",r;
    print "0020","DNS_Client_Verify_Name_Server","WAIT_RUNTIME","-","-";
    print "0030","Host_Set_Name","FIXTURE_VERIFIED","hostname",h;
    print "0040","Host_Configure_FQDN","FIXTURE_VERIFIED","hosts",s}' "$report/manifest.tsv" > "$report/results.tsv"
printf 'VERIFIED_FIXTURE\n' > "$report/status.new"
mv -fT -- "$report/status.new" "$report/status"
cat "$report/results.tsv"
echo 'Fixture baseline verified; all other tasks and native verification remain open.'
