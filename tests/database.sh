#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT HUP INT TERM
base="bin/sasd-db-health-adapter --hosts site/hosts.tsv --roles site/roles.tsv --instances site/databases.tsv --now 1700000001"
rc=0; $base --input fixtures/database/health-ok.tsv > "$tmp/ok" || rc=$?
[ "$rc" -eq 0 ]; grep -q 'source=OFFLINE.*instance=erp-primary.*green' "$tmp/ok" || grep -q 'mon.lab.invalid.*green.*source=OFFLINE.*instance=erp-primary' "$tmp/ok"
rc=0; $base --input fixtures/database/health-warning.tsv || rc=$?
[ "$rc" -eq 1 ]
rc=0; $base --input fixtures/database/health-critical.tsv || rc=$?
[ "$rc" -eq 2 ]
rc=0; $base --input fixtures/database/health-stale.tsv > "$tmp/stale" || rc=$?
[ "$rc" -eq 3 ]; grep -q 'stale or from the future' "$tmp/stale"
sed 's/visibility=complete/visibility=partial/' fixtures/database/health-ok.tsv > "$tmp/partial"
rc=0; $base --input "$tmp/partial" > "$tmp/partial-out" || rc=$?
[ "$rc" -eq 3 ]; grep -q 'visibility is incomplete' "$tmp/partial-out"
sed 's/instance=erp-primary/instance=missing-instance/' fixtures/database/health-ok.tsv > "$tmp/unknown"
rc=0; $base --input "$tmp/unknown" > "$tmp/unknown-out" || rc=$?
[ "$rc" -eq 3 ]; grep -q 'unknown database instance' "$tmp/unknown-out"
sed 's/version=10.11.6/version=5.7.0/' fixtures/database/health-ok.tsv > "$tmp/version"
rc=0; $base --input "$tmp/version" > "$tmp/version-out" || rc=$?
[ "$rc" -eq 3 ]; grep -q 'does not match inventory' "$tmp/version-out"
echo 'Database health adapter offline vertical slice: PASS'
