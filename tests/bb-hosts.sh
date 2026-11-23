#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
./bin/sasd-bb-hosts-lint --input bigbrother/bb-hosts.example > "$tmp/hosts"
grep -q 'hosts=3' "$tmp/hosts"
printf '999.1.2.3 invalid.lab.invalid # http\n' > "$tmp/bad"
if ./bin/sasd-bb-hosts-lint --input "$tmp/bad" > "$tmp/errors"; then
    echo "bad IPv4 value accepted" >&2; exit 1
fi
grep -q '^INVALID' "$tmp/errors"
echo "Big Brother-era configuration lint: PASS"
