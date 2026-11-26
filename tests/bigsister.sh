#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

bin/sasd-config-bigsister --hosts site/hosts.tsv --roles site/roles.tsv \
    --checks site/checks.tsv --services site/services.tsv --out "$tmp/bb-display.cfg"
grep -q '^%Option -DNS +BBLog$' "$tmp/bb-display.cfg"
grep -q '^web.lab.invalid .*bsdisplay$' "$tmp/bb-display.cfg"
printf 'web.lab.invalid\tdisabled\toperator\n' > "$tmp/state.tsv"
if bin/sasd-config-bigsister --hosts site/hosts.tsv --roles site/roles.tsv \
    --checks site/checks.tsv --services site/services.tsv --state "$tmp/state.tsv" | grep -q web.lab.invalid; then
    echo "disabled host emitted by Big Sister adapter" >&2
    exit 1
fi
printf 'status web.lab.invalid.http yellow (1700000000) slow\n' > "$tmp/status"
bin/sasd-status-import-bigsister --input "$tmp/status" --hosts site/hosts.tsv \
    --roles site/roles.tsv --checks site/checks.tsv > "$tmp/imported" 2> "$tmp/imported.log"
grep -q "^web.lab.invalid$(printf '\t')http$(printf '\t')yellow" "$tmp/imported"
if printf 'status web.lab.invalid.http green ok\nstatus web.lab.invalid.http red bad\n' > "$tmp/duplicate" && \
    bin/sasd-status-import-bigsister --input "$tmp/duplicate" --hosts site/hosts.tsv \
    --roles site/roles.tsv --checks site/checks.tsv > "$tmp/duplicate.out" 2>&1; then
    echo "duplicate Big Sister observation accepted" >&2
    exit 1
fi
grep -q 'duplicate external status observation' "$tmp/duplicate.out"
echo "Big Sister candidate generation and status import: PASS"
