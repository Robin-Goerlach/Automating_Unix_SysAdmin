#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
fixture=fixtures/database/health-ok.tsv
reporting=fixtures/database/health-reporting-ok.tsv
instances=site/databases.tsv
at=1700000000

adapter() {
    input=$1
    epoch=$2
    shift 2
    bin/sasd-db-health-adapter --hosts site/hosts.tsv --roles site/roles.tsv --instances "$instances" \
        --input "$input" --now "$epoch" "$@"
}
status() {
    expected=$1
    output=$2
    reason=$3
    shift 3
    rc=0
    adapter "$@" --warn-active 10 --crit-active 50 > "$output" 2> "$tmp/diagnostic" || rc=$?
    [ "$rc" -eq "$expected" ] || { cat "$tmp/diagnostic" >&2; return 1; }
    if [ -s "$output" ]; then
        awk -F '\t' 'NF != 5 || $5 !~ /^[0-9]+$/ { exit 1 }
            END { if (NR != 1) exit 1 }' "$output"
        grep -q "$reason" "$output"
    else
        [ "$expected" -eq 3 ]
        grep -q "$reason" "$tmp/diagnostic"
    fi
}
reject_observation() {
    status 3 "$tmp/rejected" "$1" "$tmp/observation" "$at"
    test ! -s "$tmp/rejected"
}
with_epoch() {
    sed "s/^observed_at=.*/observed_at=$2/" "$1"
}

server=$tmp/server
install/install-monitoring-server.sh --prefix "$server" --config site/monitoring.conf --apply > "$tmp/install"
plain=$server/etc/sasd-monitor.conf
cfg=$server/etc/offline.conf
cp "$plain" "$cfg"
cp "$instances" "$server/etc/databases.tsv"
printf 'offline_databases=databases.tsv\n' >> "$cfg"
"$server/bin/sasd-monitor-config" --config "$cfg" --check > "$tmp/config"
grep -q '^config=OK$' "$tmp/config"

latest=$server/var/status/latest
state=$server/var/status/state.tsv
history=$server/var/history/events.tsv
host=mon.lab.invalid
primary=db_erp-primary
secondary=db_erp-reporting
ingest() {
    "$server/bin/sasd-monitor-import" --config "$cfg" --input "$1" \
        --received-at "$2" --source offline-db > "$tmp/import-result"
    grep -q "^imported=$3 received=$2$" "$tmp/import-result"
}
cycle() {
    "$server/bin/sasd-monitor-cycle" --config "$cfg" --now "$1" > "$tmp/cycle"
}
assert_state() {
    awk -F '\t' -v check="$1" -v observed="$2" -v state="$3" -v epoch="$4" -v source="$5" -v message="$6" '
        $2 == "mon.lab.invalid" && $3 == check && $4 == observed && $5 == state &&
        $6 == epoch && $7 == source && index($8, message) { matches++ }
        END { exit matches != 1 }
    ' "$state"
}
assert_latest() {
    awk -F '\t' -v check="$1" -v color="$2" -v epoch="$3" '
        NR == 1 && NF == 6 && $1 == epoch && $2 == "mon.lab.invalid" &&
        $3 == check && $4 == color && $5 ~ /^source=OFFLINE diagnostic=db-health instance=/ &&
        $6 == "offline-db" { valid=1 }
        END { exit !(valid && NR == 1) }
    ' "$latest/$host.$1"
}

cycle "$at"
assert_state "$primary" none purple 0 - 'no report received'
assert_state "$secondary" none purple 0 - 'no report received'
status 0 "$tmp/ok" 'source=OFFLINE diagnostic=db-health instance=erp-primary' "$fixture" "$at"
status 0 "$tmp/second-ok" 'source=OFFLINE diagnostic=db-health instance=erp-reporting' "$reporting" "$at"
if "$server/bin/sasd-monitor-import" --config "$plain" --input "$tmp/ok" --received-at "$at" --source offline-db > "$tmp/error" 2>&1; then
    echo 'database observation accepted without lab opt-in' >&2; exit 1
fi
grep -q 'requires lab configuration' "$tmp/error"
if "$server/bin/sasd-monitor-import" --config "$cfg" --input "$tmp/ok" --received-at "$at" > "$tmp/error" 2>&1; then
    echo 'database observation accepted under generic source' >&2; exit 1
fi
grep -q 'requires the offline database source' "$tmp/error"

sed 's/^mon.lab.invalid/web.lab.invalid/' "$tmp/ok" > "$tmp/wrong-target"
if ingest "$tmp/wrong-target" "$at" 1 2> "$tmp/import-error"; then
    echo 'wrong status host accepted' >&2; exit 1
fi
grep -q 'not assigned to host' "$tmp/import-error"
cut -f 1-4 "$tmp/ok" > "$tmp/no-time"
if ingest "$tmp/no-time" "$at" 1 2> "$tmp/import-error"; then
    echo 'database record without measurement time accepted' >&2; exit 1
fi
grep -q 'requires its source marker and measurement epoch' "$tmp/import-error"
awk 'BEGIN { OFS="\t"; FS="\t" } {$5=1700000001; print}' "$tmp/ok" > "$tmp/future-status"
if ingest "$tmp/future-status" "$at" 1 2> "$tmp/import-error"; then
    echo 'future database status accepted by importer' >&2; exit 1
fi
grep -q 'measurement epoch is too far in the future' "$tmp/import-error"

cat "$tmp/ok" "$tmp/second-ok" > "$tmp/initial"
ingest "$tmp/initial" 1700000001 2
assert_latest "$primary" green "$at"
assert_latest "$secondary" green "$at"
cycle 1700000001
assert_state "$primary" green green "$at" offline-db 'below warning'
assert_state "$secondary" green green "$at" offline-db 'below warning'
cp "$history" "$tmp/history-before-repeat"
ingest "$tmp/initial" 1700000002 2
cycle 1700000002
cmp "$history" "$tmp/history-before-repeat"

# The default equality policy is inclusive at each explicit threshold.
with_epoch fixtures/database/health-warning.tsv 1700000010 | sed 's/active=15/active=10/' > "$tmp/observation"
status 1 "$tmp/warn" 'at or above warning threshold' "$tmp/observation" 1700000010
ingest "$tmp/warn" 1700000011 1
cycle 1700000011
assert_state "$primary" yellow yellow 1700000010 offline-db 'warning threshold'
assert_state "$secondary" green green "$at" offline-db 'below warning'
"$server/bin/sasd-monitor-report" --config "$cfg" --out "$tmp/warning.html"
grep -q '<td>db_erp-primary</td>.*<td>WARNING</td></tr>' "$tmp/warning.html"

future_until=$(($(date +%s) + 3600))
"$server/bin/sasd-monitor-control" --config "$cfg" --action acknowledge --host "$host" \
    --check "$primary" --until "$future_until" --operator lab --reason 'reviewed synthetic warning' > "$tmp/ack"
grep -q '^acknowledgement=OK' "$tmp/ack"
with_epoch fixtures/database/health-critical.tsv 1700000020 | sed 's/active=60/active=50/' > "$tmp/observation"
status 2 "$tmp/critical" 'at or above critical threshold' "$tmp/observation" 1700000020
with_epoch "$reporting" 1700000020 | sed 's/visibility=complete/visibility=partial/' > "$tmp/observation"
status 3 "$tmp/partial" 'visibility is incomplete' "$tmp/observation" 1700000020
cat "$tmp/critical" "$tmp/partial" > "$tmp/batch"
ingest "$tmp/batch" 1700000021 2
cycle 1700000021
assert_state "$primary" red red 1700000020 offline-db "[acknowledged until $future_until]"
assert_state "$secondary" purple purple 1700000020 offline-db 'visibility is incomplete'
"$server/bin/sasd-monitor-report" --config "$cfg" --out "$tmp/critical.html"
grep -q '<td>db_erp-primary</td>.*<td>ACKNOWLEDGED</td></tr>' "$tmp/critical.html"
grep -q '<td>db_erp-reporting</td>.*<td>UNKNOWN</td></tr>' "$tmp/critical.html"

"$server/bin/sasd-monitor-control" --config "$cfg" --action acknowledgement-clear --host "$host" \
    --check "$primary" --operator lab --reason 'review complete' > "$tmp/clear"
with_epoch "$fixture" 1700000030 > "$tmp/observation"
status 0 "$tmp/recovery" 'below warning' "$tmp/observation" 1700000030
ingest "$tmp/recovery" 1700000031 1
cycle 1700000031
assert_state "$primary" green green 1700000030 offline-db 'below warning'
"$server/bin/sasd-monitor-report" --config "$cfg" --out "$tmp/report.html"
grep -q '<tr class="green"><td>mon.lab.invalid</td><td>db_erp-primary</td><td>green</td><td>green</td><td>1700000030</td>' "$tmp/report.html"
grep -q '<tr class="purple"><td>mon.lab.invalid</td><td>db_erp-reporting</td><td>purple</td><td>purple</td><td>1700000020</td>' "$tmp/report.html"
awk -F '\t' '$2 == "mon.lab.invalid" && $3 ~ /^db_/ { print $1, $3, $4, $5, $6 }' "$history" > "$tmp/events"
cat > "$tmp/expected-events" <<'EVENTS'
1700000000 db_erp-primary none purple -
1700000000 db_erp-reporting none purple -
1700000001 db_erp-primary purple green offline-db
1700000001 db_erp-reporting purple green offline-db
1700000011 db_erp-primary green yellow offline-db
1700000021 db_erp-primary yellow red offline-db
1700000021 db_erp-reporting green purple offline-db
1700000031 db_erp-primary red green offline-db
EVENTS
cmp "$tmp/events" "$tmp/expected-events"
cycle 1700000931
assert_state "$primary" green purple 1700000030 offline-db 'stale report'
status 3 "$tmp/stale" 'observation is stale' fixtures/database/health-stale.tsv "$at"
if ingest "$tmp/stale" 1700000932 1 2> "$tmp/import-error"; then
    echo 'stale observation replaced newer state' >&2; exit 1
fi
grep -q 'older observation' "$tmp/import-error"
assert_latest "$primary" green 1700000030

# A synthetic source cannot replace another source, even under a lab config
# accidentally pointed at a directory containing authoritative records.
cp "$latest/$host.$primary" "$tmp/saved"
sed 's/offline-db$/authoritative/' "$tmp/saved" > "$latest/$host.$primary"
cp "$latest/$host.$primary" "$tmp/authoritative"
with_epoch "$fixture" 1700000940 > "$tmp/observation"
status 0 "$tmp/new" 'below warning' "$tmp/observation" 1700000940
if ingest "$tmp/new" 1700000941 1 2> "$tmp/import-error"; then
    echo 'synthetic source replaced authoritative observation' >&2; exit 1
fi
grep -q 'cannot replace a different source' "$tmp/import-error"
cmp "$tmp/authoritative" "$latest/$host.$primary"
cycle 1700000941
assert_state "$primary" none purple 0 - 'observation source does not match check'
cp "$tmp/saved" "$latest/$host.$primary"

with_epoch "$fixture" 1700000001 > "$tmp/observation"
reject_observation 'from the future'
sed 's/^instance=.*/instance=unknown/' "$fixture" > "$tmp/observation"
reject_observation 'unknown database instance'
sed 's/^host=.*/host=web.lab.invalid/' "$fixture" > "$tmp/observation"
reject_observation 'host mismatch'
sed 's/^version=.*/version=10.10.1/' "$fixture" > "$tmp/observation"
status 3 "$tmp/mismatch" 'does not match inventory' "$tmp/observation" "$at"
sed 's/^active=.*/active=5/' "$reporting" > "$tmp/observation"
status 3 "$tmp/inconsistent" 'exceed total client backends' "$tmp/observation" "$at"
sed 's/^connections=.*/connections=0/' "$fixture" > "$tmp/observation"
status 0 "$tmp/non-atomic" 'below warning' "$tmp/observation" "$at"
sed 's/^active=.*/active=unknown/' "$fixture" > "$tmp/observation"
status 3 "$tmp/unavailable" 'health metric unavailable' "$tmp/observation" "$at"
cp "$fixture" "$tmp/observation"
printf 'result=failed\n' >> "$tmp/observation"
status 3 "$tmp/failed" 'diagnostic failed' "$tmp/observation" "$at"
rc=0
adapter "$fixture" "$at" > "$tmp/no-policy" || rc=$?
[ "$rc" -eq 3 ]
grep -q 'no active-session policy' "$tmp/no-policy"
for thresholds in '10 10' '11 10' '-1 10'; do
    set -- $thresholds
    rc=0
    adapter "$fixture" "$at" --warn-active "$1" --crit-active "$2" > "$tmp/bad-policy" 2> "$tmp/diagnostic" || rc=$?
    [ "$rc" -eq 3 ]
    test ! -s "$tmp/bad-policy"
    grep -q 'invalid active session thresholds' "$tmp/diagnostic"
done

for mutation in 'product=oracle' 'host=../unsafe' 'instance=' 'version=12..' 'active=-1' 'active=NaN' \
    'active=Inf' 'connections=9999999999999999' 'source=LIVE' 'diagnostic=db-probe' 'scope=cluster' \
    'visibility=maybe' 'observed_at=NaN'; do
    sed "s|^${mutation%%=*}=.*|$mutation|" "$fixture" > "$tmp/observation"
    reject_observation 'invalid database\|not an accepted'
done
for addition in 'active=1' 'extra=value' 'INVALID=value'; do
    cp "$fixture" "$tmp/observation"
    printf '%s\n' "$addition" >> "$tmp/observation"
    reject_observation 'database observation field'
done
sed '/^observed_at=/d' "$fixture" > "$tmp/observation"
reject_observation 'missing database observation field'
sed '1d' "$fixture" > "$tmp/observation"
reject_observation 'unsupported database observation format'
cp "$fixture" "$tmp/observation"
printf 'result=ok\000\n' >> "$tmp/observation"
reject_observation 'invalid database observation field'
cp "$fixture" "$tmp/observation"
printf 'result=ok\001\n' >> "$tmp/observation"
reject_observation 'invalid database observation field'
cp "$fixture" "$tmp/observation"
awk 'BEGIN { printf "result="; for (i = 0; i < 241; i++) printf "x"; print "" }' >> "$tmp/observation"
reject_observation 'invalid database observation field'
head -c 4097 /dev/zero > "$tmp/observation"
reject_observation 'exceeds byte limit'

status 3 "$tmp/missing-state" 'host state file is missing' "$fixture" "$at" --state "$tmp/missing-state.tsv"
test ! -s "$tmp/missing-state"
printf 'garbage\n' > "$tmp/lifecycle"
status 3 "$tmp/bad-state" 'invalid host state' "$fixture" "$at" --state "$tmp/lifecycle"
test ! -s "$tmp/bad-state"
if [ "$(id -u)" -ne 0 ]; then
    chmod 000 "$tmp/lifecycle"
    status 3 "$tmp/unreadable-state" 'cannot read host state' "$fixture" "$at" --state "$tmp/lifecycle"
    test ! -s "$tmp/unreadable-state"
    chmod 600 "$tmp/lifecycle"
fi
for lifecycle in enabled disabled removed; do
    printf 'mon.lab.invalid\t%s\toperator\n' "$lifecycle" > "$tmp/lifecycle"
    if [ "$lifecycle" = enabled ]; then
        status 0 "$tmp/lifecycle-result" 'below warning' "$fixture" "$at" --state "$tmp/lifecycle"
    else
        status 3 "$tmp/lifecycle-result" 'database host or instance is not enabled' "$fixture" "$at" --state "$tmp/lifecycle"
        test ! -s "$tmp/lifecycle-result"
    fi
done
printf 'web.lab.invalid\tdisabled\toperator\n' > "$tmp/lifecycle"
status 0 "$tmp/sparse-result" 'below warning' "$fixture" "$at" --state "$tmp/lifecycle"

instances=$tmp/instances.tsv
# Unsupported but syntactically valid and inventory-matching versions are UNKNOWN.
sed 's/15\tpostgresql_15/99\tpostgresql_99/' site/databases.tsv > "$instances"
sed 's/version=15.4/version=99.1/' "$reporting" > "$tmp/observation"
status 3 "$tmp/unsupported" 'outside the synthetic support matrix' "$tmp/observation" "$at"
ingest "$tmp/unsupported" 1700000001 1 2> "$tmp/import-error" && exit 1
grep -q 'older observation' "$tmp/import-error"
with_epoch "$tmp/observation" 1700000945 > "$tmp/version-update"
cp "$instances" "$server/etc/databases.tsv"
status 3 "$tmp/unsupported" 'outside the synthetic support matrix' "$tmp/version-update" 1700000945
ingest "$tmp/unsupported" 1700000946 1
cycle 1700000946
assert_state "$secondary" purple purple 1700000945 offline-db 'outside the synthetic support matrix'

printf 'erp-primary\tmon.lab.invalid\tmysql\t8.0\tmysql_8_0\tenabled\n' > "$instances"
sed -e 's/product=mariadb/product=mysql/' -e 's/version=10.11.6/version=8.0.36/' "$fixture" > "$tmp/observation"
status 0 "$tmp/mysql" 'product=mysql version=8.0.36' "$tmp/observation" "$at"
printf 'abcdefghijklmnopqrstuvwxyzabcd\tmon.lab.invalid\tmysql\t8.0\tmysql_8_0\tenabled\n' > "$instances"
status 3 "$tmp/name-length" 'invalid database instance record' "$tmp/observation" "$at"
test ! -s "$tmp/name-length"
cat site/databases.tsv > "$instances"
printf 'ERP-primary\tmon.lab.invalid\tmysql\t8.0\tmysql_8_0\tenabled\n' >> "$instances"
status 3 "$tmp/name-case" 'duplicate database instance' "$fixture" "$at"
test ! -s "$tmp/name-case"

for lifecycle in disabled removed; do
    sed "/^erp-primary/s/enabled$/$lifecycle/" site/databases.tsv > "$instances"
    cp "$instances" "$server/etc/databases.tsv"
    status 3 "$tmp/inactive" 'database host or instance is not enabled' "$fixture" "$at"
    test ! -s "$tmp/inactive"
    if ingest "$tmp/new" 1700000941 1 2> "$tmp/import-error"; then
        echo 'inactive database instance imported' >&2; exit 1
    fi
    grep -q 'unknown check' "$tmp/import-error"
    cycle 1700000941
    if grep -q 'db_erp-primary' "$state"; then
        echo 'inactive database instance still in active state' >&2; exit 1
    fi
done
cp site/databases.tsv "$server/etc/databases.tsv"
printf 'mon.lab.invalid\tremoved\toperator\n' > "$server/etc/hosts.tsv.state"
cycle 1700000947
if grep -q 'db_erp-' "$state"; then
    echo 'removed host still has active database checks' >&2; exit 1
fi
grep -q 'db_erp-primary' "$history"
printf 'db_erp-primary\t*\tconflicting static check\n' >> "$server/etc/checks.tsv"
if "$server/bin/sasd-monitor-config" --config "$cfg" > "$tmp/collision" 2>&1; then
    echo 'database check name collision accepted' >&2; exit 1
fi
grep -q 'database check overlaps configured check' "$tmp/collision"
echo 'Database health adapter, shared import, independent states, history, operations and report: PASS'
