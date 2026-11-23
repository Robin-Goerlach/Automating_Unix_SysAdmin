#!/bin/sh
# Test harness may use newer Unix utilities; runtime programs remain small.
set -eu
cd "$(dirname "$0")/.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir "$tmp/status"
./bin/sasd-host-facts > "$tmp/host"
test -s "$tmp/host"
./bin/sasd-disk-watch --host lab-host --input fixtures/df/healthy.txt > "$tmp/disk"
grep -q 'lab-host[[:space:]]disk[[:space:]]yellow' "$tmp/disk"
./bin/sasd-disk-watch --host lab-host --input fixtures/df/critical.txt > "$tmp/disk-red"
grep -q 'red' "$tmp/disk-red"
./bin/sasd-status-store --spool "$tmp/status" --input fixtures/status/disk.tsv > "$tmp/store"
grep -q 'stored=2' "$tmp/store"
./bin/sasd-status-board --spool "$tmp/status" --out "$tmp/board.html"
grep -q 'DNS service unavailable' "$tmp/board.html"
grep -q 'class="red"' "$tmp/board.html"
./bin/sasd-config-drift --root fixtures/config/actual --golden fixtures/config/golden --manifest fixtures/config/manifest.tsv > "$tmp/drift"
grep -q '^OK' "$tmp/drift"
mkdir -p "$tmp/actual/etc"
printf '%s\n' changed > "$tmp/actual/etc/ntp.conf"
if ./bin/sasd-config-drift --root "$tmp/actual" --golden fixtures/config/golden --manifest fixtures/config/manifest.tsv > "$tmp/changed"; then
    echo "expected drift exit status" >&2
    exit 1
fi
grep -q '^DRIFT' "$tmp/changed"
./bin/sasd-mrtg-counter --input fixtures/mrtg/ifcounters.tsv > "$tmp/counters"
test "$(wc -l < "$tmp/counters")" -eq 4
test "$(head -n 1 "$tmp/counters")" = 120000
# HTML escape regression: status input must not become executable markup.
printf 'lab-host\thttp\tred\t&lt;script&gt; no injection\n' > "$tmp/injection"
./bin/sasd-status-store --spool "$tmp/status" --input "$tmp/injection" > /dev/null
./bin/sasd-status-board --spool "$tmp/status" --out "$tmp/board.html"
grep -q '&amp;lt;script&amp;gt;' "$tmp/board.html"
if printf 'evil/host\tdisk\tred\tunsafe\n' | ./bin/sasd-status-store --spool "$tmp/status" >/dev/null 2>&1; then
    echo "unsafe host accepted" >&2
    exit 1
fi
echo "SASD smoke tests: PASS"
