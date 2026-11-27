#!/bin/sh
# Reproducible cross-product offline laboratory.  It never contacts an
# inventory address, starts a service, or writes outside its temporary tree.
set -eu
root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
lab=$(mktemp -d)
trap 'rm -rf "$lab"' EXIT HUP INT TERM
model=$lab/model
out=$lab/candidates
server=$lab/monitor
mkdir "$model" "$out"
cp "$root/site/hosts.tsv" "$root/site/roles.tsv" "$root/site/checks.tsv" "$root/site/services.tsv" "$root/site/databases.tsv" "$model/"
mkdir "$model/bin"
cp "$root/site/monitoring.conf" "$model/monitoring.conf"
cp "$root/bin/sasd-mrtg-counter" "$model/bin/sasd-mrtg-counter"

"$root/bin/sasd-site-inventory" --input "$model/hosts.tsv" --roles "$model/roles.tsv" --check > "$lab/inventory"
"$root/bin/sasd-site-services" --hosts "$model/hosts.tsv" --roles "$model/roles.tsv" --checks "$model/checks.tsv" --services "$model/services.tsv" --check > "$lab/services"
"$root/bin/sasd-site-consistency" --hosts "$model/hosts.tsv" --roles "$model/roles.tsv" --checks "$model/checks.tsv" --services "$model/services.tsv" --monitoring "$root/site/monitoring.conf" --check > "$lab/consistency"
grep -q '^hosts=4 ' "$lab/inventory"
grep -q '^hosts=4 ' "$lab/consistency"
echo 'A site model validation: PASS'

"$root/bin/sasd-host-admin" --input "$model/hosts.tsv" --roles "$model/roles.tsv" --operation add --host lab-web.lab.invalid --record 'lab-web.lab.invalid	192.0.2.50	unix	web	lab	web' --apply > "$lab/add"
"$root/bin/sasd-host-admin" --input "$model/hosts.tsv" --roles "$model/roles.tsv" --operation update --host cfg.lab.invalid --record 'cfg.lab.invalid	192.0.2.42	unix	web	lab	web' --apply > "$lab/update"
"$root/bin/sasd-host-admin" --input "$model/hosts.tsv" --roles "$model/roles.tsv" --operation disable --host web.lab.invalid --apply > "$lab/disable"
"$root/bin/sasd-host-admin" --input "$model/hosts.tsv" --roles "$model/roles.tsv" --operation remove --host mail.lab.invalid --apply > "$lab/remove"
grep -q 'disable' "$model/hosts.tsv.history.tsv"
grep -q 'remove' "$model/hosts.tsv.history.tsv"
echo 'A lifecycle add/update/disable/remove/history: PASS'

"$root/bin/sasd-site-config" --hosts "$model/hosts.tsv" --roles "$model/roles.tsv" --checks "$model/checks.tsv" --services "$model/services.tsv" --state "$model/hosts.tsv.state" --out "$out/site" --apply > "$lab/site-config"
"$root/bin/sasd-config-cfengine1" --hosts "$model/hosts.tsv" --roles "$model/roles.tsv" --state "$model/hosts.tsv.state" --out "$out/cfengine1.conf" --apply > "$lab/cfengine1"
"$root/bin/sasd-config-cfengine2" --hosts "$model/hosts.tsv" --roles "$model/roles.tsv" --state "$model/hosts.tsv.state" --out "$out/cfengine2.conf" --apply > "$lab/cfengine2"
"$root/bin/sasd-config-bigbrother" --hosts "$model/hosts.tsv" --roles "$model/roles.tsv" --checks "$model/checks.tsv" --services "$model/services.tsv" --state "$model/hosts.tsv.state" --out "$out/bb-hosts"
"$root/bin/sasd-config-bigsister" --hosts "$model/hosts.tsv" --roles "$model/roles.tsv" --checks "$model/checks.tsv" --services "$model/services.tsv" --state "$model/hosts.tsv.state" --out "$out/bigsister.cfg"
"$root/bin/sasd-config-netsaint" --hosts "$model/hosts.tsv" --roles "$model/roles.tsv" --checks "$model/checks.tsv" --services "$model/services.tsv" --state "$model/hosts.tsv.state" --out "$out/netsaint.cfg"
"$root/bin/sasd-config-nagios" --hosts "$model/hosts.tsv" --roles "$model/roles.tsv" --checks "$model/checks.tsv" --services "$model/services.tsv" --state "$model/hosts.tsv.state" --disk-fixture "$root/fixtures/df/healthy.txt" --out "$out/nagios.cfg" --force
"$root/bin/sasd-config-ganglia" --hosts "$model/hosts.tsv" --roles "$model/roles.tsv" --state "$model/hosts.tsv.state" --gmond-out "$out/gmond.conf" --gmetad-out "$out/gmetad.conf" --force
grep -q 'lab-web.lab.invalid' "$out/bb-hosts"
if awk '$2 == "web.lab.invalid" || $2 == "mail.lab.invalid" { found=1 } END { exit found ? 0 : 1 }' "$out/bb-hosts"; then
    echo 'disabled or removed host emitted by Big Brother adapter' >&2; exit 1
fi
grep -q 'check_command.*sasd-check!disk!' "$out/nagios.cfg"
printf 'Filesystem 1024-blocks Used Available Capacity Mounted on\n/dev/test 100 20 80 20%% /\n' > "$lab/nagios-df"
"$root/bin/sasd-check-plugin" --plugin "$root/bin/sasd-check-adapter" --check sasd --arg disk --arg lab-web.lab.invalid --arg "$lab/nagios-df" > "$lab/nagios-check"
grep -q '^green.*GREEN -' "$lab/nagios-check"
grep -q 'cluster {' "$out/gmond.conf"
grep -q 'data_source' "$out/gmetad.conf"
printf 'lab-web.lab.invalid\tlab\t1700000000\tcpu\t12.5\tpercent\tgauge\n' > "$lab/ganglia.tsv"
"$root/bin/sasd-ganglia-metric" --input "$lab/ganglia.tsv" --now 1700000001 > "$lab/ganglia.out"
grep -q '^OK	lab-web.lab.invalid	lab' "$lab/ganglia.out"
"$root/bin/sasd-db-health-adapter" --input "$root/fixtures/database/health-ok.tsv" --hosts "$model/hosts.tsv" --roles "$model/roles.tsv" --instances "$model/databases.tsv" --state "$model/hosts.tsv.state" --now 1700000001 > "$lab/database.out"
grep -q 'mon.lab.invalid.*green.*source=OFFLINE.*instance=erp-primary' "$lab/database.out"
echo 'B candidate generation (SASD/CFEngine 1/2/Big Brother/Big Sister/NetSaint/Nagios/Ganglia/database): PASS'

deploy_stage=$lab/deploy-stage
deploy_target=$lab/deploy-target
deploy_plan=$lab/deploy.plan
mkdir -m 0700 "$deploy_target"
"$root/bin/sasd-config-deploy" --hosts "$model/hosts.tsv" --roles "$model/roles.tsv" --checks "$model/checks.tsv" --services "$model/services.tsv" --state "$model/hosts.tsv.state" --staging "$deploy_stage" --target "$deploy_target" --plan "$deploy_plan" --prepare > "$lab/deploy-prepare"
"$root/bin/sasd-config-deploy" --hosts "$model/hosts.tsv" --roles "$model/roles.tsv" --checks "$model/checks.tsv" --services "$model/services.tsv" --state "$model/hosts.tsv.state" --staging "$deploy_stage" --target "$deploy_target" --plan "$deploy_plan" --dry-run > "$lab/deploy-dry-run"
grep -q 'changes=11 status=DRY-RUN' "$lab/deploy-dry-run"
"$root/bin/sasd-config-deploy" --hosts "$model/hosts.tsv" --roles "$model/roles.tsv" --checks "$model/checks.tsv" --services "$model/services.tsv" --state "$model/hosts.tsv.state" --staging "$deploy_stage" --target "$deploy_target" --plan "$deploy_plan" --apply > "$lab/deploy-apply"
"$root/bin/sasd-config-deploy" --hosts "$model/hosts.tsv" --roles "$model/roles.tsv" --checks "$model/checks.tsv" --services "$model/services.tsv" --state "$model/hosts.tsv.state" --staging "$deploy_stage" --target "$deploy_target" --plan "$deploy_plan" --dry-run > "$lab/deploy-repeat"
grep -q 'changes=0 status=DRY-RUN' "$lab/deploy-repeat"
test -f "$deploy_target/bigsister/bb-display.cfg"
test -f "$deploy_target/bigsister/uxmon-net"
test -f "$deploy_target/netsaint/hosts.cfg"
test -f "$deploy_target/nagios/hosts.cfg"
test -f "$deploy_target/ganglia/gmond.conf"
test -f "$deploy_target/ganglia/gmetad.conf"
echo 'B controlled staging, dry-run, apply and repeat: PASS'

"$root/bin/sasd-monitor-mrtg" --config "$model/monitoring.conf" --host-state "$model/hosts.tsv.state" --out "$out/mrtg.cfg" --force > "$lab/mrtg"
"$root/install/install-monitoring-server.sh" --prefix "$server" --config "$root/site/monitoring.conf" --apply > "$lab/install"
cp "$model/hosts.tsv" "$model/roles.tsv" "$model/checks.tsv" "$server/etc/"
cp "$model/hosts.tsv.state" "$server/etc/hosts.tsv.state"
"$server/bin/sasd-monitor-config" --config "$server/etc/sasd-monitor.conf" --check > "$lab/monitor-config"
grep -q 'web.lab.invalid.*disabled' "$server/etc/hosts.tsv.state"
grep -q 'mail.lab.invalid.*removed' "$server/etc/hosts.tsv.state"
echo 'B/C SASD monitoring candidate and disposable server: PASS'

printf 'lab-web.lab.invalid\tdisk\tgreen\tinitial healthy\n' > "$lab/green.tsv"
"$server/bin/sasd-monitor-import" --config "$server/etc/sasd-monitor.conf" --input "$lab/green.tsv" --received-at 1000 --source sasd > "$lab/import-green"
"$server/bin/sasd-monitor-cycle" --config "$server/etc/sasd-monitor.conf" --now 1001 > "$lab/cycle-green"
grep -q 'lab-web.lab.invalid.*disk.*green' "$server/var/status/state.tsv"
printf 'lab-web.lab.invalid\tdisk\tyellow\tdegraded\n' > "$lab/disk-yellow.tsv"
"$server/bin/sasd-monitor-import" --config "$server/etc/sasd-monitor.conf" --input "$lab/disk-yellow.tsv" --received-at 1005 --source sasd > "$lab/import-disk-yellow"
"$server/bin/sasd-monitor-cycle" --config "$server/etc/sasd-monitor.conf" --now 1006 > "$lab/cycle-disk-yellow"
grep -q 'lab-web.lab.invalid.*disk.*yellow' "$server/var/status/state.tsv"
printf 'lab-web.lab.invalid\tdisk\tred\tfull\n' > "$lab/disk-red.tsv"
"$server/bin/sasd-monitor-import" --config "$server/etc/sasd-monitor.conf" --input "$lab/disk-red.tsv" --received-at 1010 --source sasd > "$lab/import-disk-red"
"$server/bin/sasd-monitor-cycle" --config "$server/etc/sasd-monitor.conf" --now 1011 > "$lab/cycle-disk-red"
grep -q 'lab-web.lab.invalid.*disk.*red' "$server/var/status/state.tsv"

printf 'status lab-web.lab.invalid.http yellow (1010) slow response\n' > "$lab/bb-input"
"$root/bin/sasd-status-import-bigbrother" --input "$lab/bb-input" --hosts "$model/hosts.tsv" --roles "$model/roles.tsv" --checks "$model/checks.tsv" > "$lab/bb-status"
"$server/bin/sasd-monitor-import" --config "$server/etc/sasd-monitor.conf" --input "$lab/bb-status" --received-at 1010 --source bigbrother > "$lab/import-yellow"
"$server/bin/sasd-monitor-cycle" --config "$server/etc/sasd-monitor.conf" --now 1011 > "$lab/cycle-yellow"
grep -q 'lab-web.lab.invalid.*http.*yellow' "$server/var/status/state.tsv"

printf 'status lab-web.lab.invalid.http red (1020) service failed\n' > "$lab/bs-input"
"$root/bin/sasd-status-import-bigsister" --input "$lab/bs-input" --hosts "$model/hosts.tsv" --roles "$model/roles.tsv" --checks "$model/checks.tsv" > "$lab/bs-status"
"$server/bin/sasd-monitor-import" --config "$server/etc/sasd-monitor.conf" --input "$lab/bs-status" --received-at 1020 --source bigsister > "$lab/import-red"
"$server/bin/sasd-monitor-cycle" --config "$server/etc/sasd-monitor.conf" --now 1021 > "$lab/cycle-red"
grep -q 'lab-web.lab.invalid.*http.*red' "$server/var/status/state.tsv"
grep -q 'cfg.lab.invalid.*purple' "$server/var/status/state.tsv"

printf 'lab-web.lab.invalid\tdisk\tgreen\trecovered\n' > "$lab/recovery.tsv"
"$server/bin/sasd-monitor-import" --config "$server/etc/sasd-monitor.conf" --input "$lab/recovery.tsv" --received-at 1030 --source sasd > "$lab/import-recovery"
"$server/bin/sasd-monitor-cycle" --config "$server/etc/sasd-monitor.conf" --now 1031 > "$lab/cycle-recovery"
grep -q 'lab-web.lab.invalid.*disk.*green' "$server/var/status/state.tsv"
if printf 'lab-web.lab.invalid\tdisk\tgreen\tforged\t9999999999\n' | "$server/bin/sasd-monitor-import" --config "$server/etc/sasd-monitor.conf" --received-at 1032 --source forged > "$lab/future-error" 2>&1; then
    echo 'future measurement accepted' >&2; exit 1
fi
if printf 'lab-web.lab.invalid\tdisk\tgreen\told\t1020\n' | "$server/bin/sasd-monitor-import" --config "$server/etc/sasd-monitor.conf" --received-at 1032 --source late > "$lab/late-error" 2>&1; then
    echo 'older observation replaced newer state' >&2; exit 1
fi
if printf 'unknown.lab.invalid\tdisk\tgreen\tbad\n' | "$server/bin/sasd-monitor-import" --config "$server/etc/sasd-monitor.conf" --received-at 1032 --source external > "$lab/unknown-error" 2>&1; then
    echo 'unknown host accepted' >&2; exit 1
fi
"$server/bin/sasd-monitor-report" --config "$server/etc/sasd-monitor.conf" --out "$lab/report.html"
grep -q 'lab-web.lab.invalid' "$lab/report.html"
echo 'C monitoring green/yellow/red/missing/recovery/conflict/unknown: PASS'
echo 'D static administrator report: PASS'
echo 'E native product daemons, network boot, and production deployment: SKIPPED'
echo "artifacts=$out report=$lab/report.html"
echo 'SASD integrated offline site laboratory: PASS'
