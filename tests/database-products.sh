#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
server=$tmp/server
install/install-monitoring-server.sh --prefix "$server" --config site/monitoring.conf --apply > "$tmp/install"
cfg=$server/etc/sasd-monitor.conf
cp site/databases.tsv "$server/etc/"
printf 'offline_databases=databases.tsv\n' >> "$cfg"

host=mon.lab.invalid
primary=db_erp-primary
secondary=db_erp-reporting
now=$(date +%s)
first=$((now - 10))
second=$((now - 5))
adapter() {
    bin/sasd-db-health-adapter --hosts site/hosts.tsv --roles site/roles.tsv \
        --instances site/databases.tsv --now "$now" "$@"
}
for product in netsaint nagios; do
    "bin/sasd-config-$product" --hosts site/hosts.tsv --roles site/roles.tsv \
        --checks site/checks.tsv --services site/services.tsv \
        --database-config "$cfg" > "$tmp/$product.cfg"
done
if bin/sasd-config-nagios --hosts site/hosts.tsv --roles site/roles.tsv \
    --checks site/checks.tsv --services site/services.tsv \
    --database-config "$cfg" --out "$server/etc/databases.tsv" --force > "$tmp/overlap" 2>&1; then
    echo 'database candidate overwrote its registry' >&2; exit 1
fi
grep -q 'overlaps an input file' "$tmp/overlap"
check_plugins() {
    check=$1
    expected=$2
    label=$3
    for product in netsaint nagios; do
        rc=0
        perl tests/classic-candidate-command.pl "$tmp/$product.cfg" "$host" "$check" > "$tmp/plugin" || rc=$?
        [ "$rc" -eq "$expected" ]
        grep -q "$label - .*source=OFFLINE" "$tmp/plugin"
    done
}
check_plugins "$primary" 3 UNKNOWN
check_plugins "$secondary" 3 UNKNOWN

sed "s/^observed_at=.*/observed_at=$first/" fixtures/database/health-ok.tsv > "$tmp/primary"
sed "s/^observed_at=.*/observed_at=$first/" fixtures/database/health-reporting-ok.tsv > "$tmp/secondary"
for file in primary secondary; do
    adapter --input "$tmp/$file" --warn-active 10 --crit-active 50 >> "$tmp/status"
done
import_cycle() {
    "$server/bin/sasd-monitor-import" --config "$cfg" --input "$tmp/status" \
        --source offline-db --received-at "$now" > "$tmp/import"
    "$server/bin/sasd-monitor-cycle" --config "$cfg" --now "$now" > "$tmp/cycle"
}
import_cycle
check_plugins "$primary" 0 OK
check_plugins "$secondary" 0 OK
sed "s/^observed_at=.*/observed_at=$second/" fixtures/database/health-critical.tsv > "$tmp/critical"
sed -e "s/^observed_at=.*/observed_at=$second/" -e 's/^visibility=.*/visibility=partial/' \
    fixtures/database/health-reporting-ok.tsv > "$tmp/partial"
rc=0
adapter --input "$tmp/critical" --warn-active 10 --crit-active 50 > "$tmp/status" || rc=$?
[ "$rc" -eq 2 ]
rc=0
adapter --input "$tmp/partial" --warn-active 10 --crit-active 50 >> "$tmp/status" || rc=$?
[ "$rc" -eq 3 ]
import_cycle
check_plugins "$primary" 2 CRITICAL
check_plugins "$secondary" 3 UNKNOWN
rc=0
bin/sasd-check-adapter "$primary" web.lab.invalid "$cfg" > "$tmp/wrong-host" || rc=$?
[ "$rc" -eq 3 ]
grep -q 'not assigned' "$tmp/wrong-host"

# Exercise each product's existing synthetic parser with the host-bound
# registry. The projection stays a review artifact outside either daemon.
for product in bigbrother bigsister; do
    bin/sasd-db-status-export --config "$cfg" --product "$product" --now "$now" > "$tmp/export"
    perl -Ilib -MSASD::Monitor=read_inventory,read_offline_db_checks,read_external_status -e '
        my ($input,$file,$product,$epoch) = @ARGV;
        my ($cfg,$checks) = read_offline_db_checks($file);
        my ($hosts) = read_inventory($cfg->{inventory_path},$cfg->{roles_path});
        my $rows = read_external_status($input,$product,$hosts,$checks);
        @$rows == 2 or die "wrong export count\n";
        for my $row (@$rows) {
            my ($host,$check,$color,$message,$observed) = @$row;
            my %expected = ("db_erp-primary"=>"red","db_erp-reporting"=>"purple");
            $host eq "mon.lab.invalid" && $observed eq $epoch &&
                $expected{$check} eq $color && $message =~ /source=OFFLINE/
                or die "wrong external database status\n";
        }
    ' "$tmp/export" "$cfg" "$product" "$second"
    bin/sasd-db-status-export --config "$cfg" --product "$product" --now "$((second + 901))" > "$tmp/stale"
    [ "$(grep -c 'purple .*stale database state' "$tmp/stale")" -eq 2 ]
done

# MRTG uses live polling time for freshness and the first two gauge
# values. Uptime is its third external-target line.
adapter --input "$tmp/primary" --format mrtg --instance erp-primary > "$tmp/mrtg"
printf '8\n1\n53001\nmon.lab.invalid/erp-primary\n' > "$tmp/mrtg-expected"
cmp "$tmp/mrtg" "$tmp/mrtg-expected"
rc=0
adapter --input "$tmp/partial" --format mrtg --instance erp-reporting > "$tmp/mrtg-missing" 2> "$tmp/error" || rc=$?
[ "$rc" -eq 3 ]
test ! -s "$tmp/mrtg-missing"
rc=0
adapter --input "$tmp/primary" --format mrtg --instance erp-reporting > "$tmp/mrtg-wrong" 2> "$tmp/error" || rc=$?
[ "$rc" -eq 3 ]
test ! -s "$tmp/mrtg-wrong"
adapter --input "$tmp/primary" --format rrd --instance erp-primary > "$tmp/sample-primary"
rc=0
adapter --input "$tmp/partial" --format rrd --instance erp-reporting > "$tmp/sample-secondary" || rc=$?
[ "$rc" -eq 3 ]

mkdir "$tmp/mock" "$tmp/rrd"
export RRD_ARGUMENTS="$tmp/rrd-arguments"
cat > "$tmp/mock/rrdtool" <<'MOCK'
#!/bin/sh
printf '%s\n' "$@" > "$RRD_ARGUMENTS"
case "$1" in create) : > "$2" ;; update) test -f "$2" ;; *) exit 1 ;; esac
MOCK
chmod 700 "$tmp/mock/rrdtool"
PATH=$tmp/mock:$PATH
export PATH
for check in "$primary" "$secondary"; do
    bin/sasd-rrd-cycle create-database "$tmp/rrd" "$host" "$check" "$((first - 1))"
    expected_file=$tmp/rrd/$host.$check.rrd
    test -f "$expected_file"
    grep -qx 'DS:connections:GAUGE:600:0:U' "$RRD_ARGUMENTS"
    grep -qx 'DS:active:GAUGE:600:0:U' "$RRD_ARGUMENTS"
    grep -qx 'DS:uptime:GAUGE:600:0:U' "$RRD_ARGUMENTS"
done
bin/sasd-rrd-cycle update-database "$tmp/rrd" "$tmp/sample-primary"
printf 'update\n%s\n--template\nconnections:active:uptime\n%s:8:1:53001\n' \
    "$tmp/rrd/$host.$primary.rrd" "$first" > "$tmp/rrd-expected"
cmp "$RRD_ARGUMENTS" "$tmp/rrd-expected"
bin/sasd-rrd-cycle update-database "$tmp/rrd" "$tmp/sample-secondary"
printf 'update\n%s\n--template\nconnections:active:uptime\n%s:U:U:U\n' \
    "$tmp/rrd/$host.$secondary.rrd" "$second" > "$tmp/rrd-expected"
cmp "$RRD_ARGUMENTS" "$tmp/rrd-expected"
cat "$tmp/sample-primary" "$tmp/sample-secondary" > "$tmp/two-samples"
printf '%s\t%s\t%s:1:2:NaN\n' "$host" "$primary" "$first" > "$tmp/bad-rrd"
for sample in two-samples bad-rrd; do
    if bin/sasd-rrd-cycle update-database "$tmp/rrd" "$tmp/$sample" > "$tmp/error" 2>&1; then
        echo 'invalid RRD update sample accepted' >&2; exit 1
    fi
    cmp "$RRD_ARGUMENTS" "$tmp/rrd-expected"
done

bin/sasd-rrd-cycle create "$tmp/rrd/legacy.rrd"
grep -qx 'DS:in:COUNTER:600:0:U' "$RRD_ARGUMENTS"
bin/sasd-rrd-cycle update "$tmp/rrd/legacy.rrd" 12 45
grep -qx 'N:12:45' "$RRD_ARGUMENTS"

sed '/^erp-primary/s/enabled$/disabled/' site/databases.tsv > "$server/etc/databases.tsv"
bin/sasd-db-status-export --config "$cfg" --product bigsister --now "$now" > "$tmp/disabled"
[ "$(wc -l < "$tmp/disabled")" -eq 1 ]
grep -q 'db_erp-reporting' "$tmp/disabled"
rc=0
bin/sasd-check-adapter "$primary" "$host" "$cfg" > "$tmp/disabled-plugin" || rc=$?
[ "$rc" -eq 3 ]
grep -q 'not assigned' "$tmp/disabled-plugin"
echo 'Database offline NetSaint, Nagios, Big Brother, Big Sister and time-series candidates: PASS'
