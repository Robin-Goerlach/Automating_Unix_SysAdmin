#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

bin/sasd-config-bigbrother --hosts site/hosts.tsv --roles site/roles.tsv \
    --services site/services.tsv --out "$tmp/bb-hosts"
grep -q '^192.0.2.11 web.lab.invalid # conn config-audit disk http$' "$tmp/bb-hosts"
printf 'web.lab.invalid\tdisabled\toperator\n' > "$tmp/state.tsv"
if bin/sasd-config-bigbrother --hosts site/hosts.tsv --roles site/roles.tsv \
    --services site/services.tsv --state "$tmp/state.tsv" | grep -q web.lab.invalid; then
    echo "disabled host emitted by Big Brother adapter" >&2
    exit 1
fi
if bin/sasd-config-bigbrother --hosts site/hosts.tsv --roles site/roles.tsv \
    --services site/services.tsv --out site/hosts.tsv --force > "$tmp/error" 2>&1; then
    echo "Big Brother input overwrite accepted" >&2
    exit 1
fi
grep -q 'output path overlaps an input file' "$tmp/error"
echo "Big Brother candidate generation: PASS"
