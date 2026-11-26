#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

bin/sasd-config-bigbrother --hosts site/hosts.tsv --roles site/roles.tsv \
    --checks site/checks.tsv --services site/services.tsv --out "$tmp/bb-hosts"
grep -q '^192.0.2.11 web.lab.invalid # conn config-audit disk http$' "$tmp/bb-hosts"
printf 'web.lab.invalid\tdisabled\toperator\n' > "$tmp/state.tsv"
if bin/sasd-config-bigbrother --hosts site/hosts.tsv --roles site/roles.tsv \
    --checks site/checks.tsv --services site/services.tsv --state "$tmp/state.tsv" | grep -q web.lab.invalid; then
    echo "disabled host emitted by Big Brother adapter" >&2
    exit 1
fi
if bin/sasd-config-bigbrother --hosts site/hosts.tsv --roles site/roles.tsv \
    --checks site/checks.tsv --services site/services.tsv --out site/hosts.tsv --force > "$tmp/error" 2>&1; then
    echo "Big Brother input overwrite accepted" >&2
    exit 1
fi
grep -q 'output path overlaps an input file' "$tmp/error"
printf 'status web.lab.invalid.http green (1700000000) http OK\n' > "$tmp/status"
bin/sasd-status-import-bigbrother --input "$tmp/status" --hosts site/hosts.tsv \
    --roles site/roles.tsv --checks site/checks.tsv > "$tmp/imported" 2> "$tmp/imported.log"
grep -q "^web.lab.invalid$(printf '\t')http$(printf '\t')green" "$tmp/imported"
if printf 'status web.lab.invalid.http green one\nstatus web.lab.invalid.http red two\n' > "$tmp/duplicate" && \
    bin/sasd-status-import-bigbrother --input "$tmp/duplicate" --hosts site/hosts.tsv \
    --roles site/roles.tsv --checks site/checks.tsv > "$tmp/duplicate.out" 2>&1; then
    echo "duplicate Big Brother observation accepted" >&2
    exit 1
fi
grep -q 'duplicate external status observation' "$tmp/duplicate.out"
echo "Big Brother candidate generation: PASS"
