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
mkdir -p "$tmp/symlink-target/etc" "$tmp/symlink-root"
printf 'safe\n' > "$tmp/symlink-target/etc/ntp.conf"
ln -s "$tmp/symlink-target" "$tmp/symlink-root/alias"
printf 'alias/etc/ntp.conf\tetc/ntp.conf\n' > "$tmp/symlink-manifest.tsv"
if ./bin/sasd-config-drift --root "$tmp/symlink-root" --golden fixtures/config/golden --manifest "$tmp/symlink-manifest.tsv" > "$tmp/symlink-drift"; then
    echo "ancestor symlink accepted" >&2
    exit 1
fi
grep -q '^UNSAFE' "$tmp/symlink-drift"
./bin/sasd-mrtg-counter --input fixtures/mrtg/ifcounters.tsv > "$tmp/counters"
test "$(wc -l < "$tmp/counters")" -eq 4
test "$(head -n 1 "$tmp/counters")" = 120000
# The input fixture may have been checked out as CRLF on an existing WSL clone.
# Accept CRLF data without accepting control characters in the device name.
printf '120000\t340000\t86400\tlab-router\r\n' > "$tmp/mrtg-crlf.tsv"
./bin/sasd-mrtg-counter --input "$tmp/mrtg-crlf.tsv" > "$tmp/mrtg-crlf-out"
test "$(wc -l < "$tmp/mrtg-crlf-out")" -eq 4
test "$(tail -n 1 "$tmp/mrtg-crlf-out")" = lab-router
printf '120000\t340000\t86400\tlab-\rrouter\n' > "$tmp/mrtg-bad.tsv"
if ./bin/sasd-mrtg-counter --input "$tmp/mrtg-bad.tsv" > /dev/null 2>&1; then
    echo "MRTG adapter accepted an embedded control character" >&2
    exit 1
fi
# HTML escape regression: status input must not become executable markup.
printf 'lab-host\thttp\tred\t&lt;script&gt; no injection\n' > "$tmp/injection"
./bin/sasd-status-store --spool "$tmp/status" --input "$tmp/injection" > /dev/null
./bin/sasd-status-board --spool "$tmp/status" --out "$tmp/board.html"
grep -q '&amp;lt;script&amp;gt;' "$tmp/board.html"
if printf 'evil/host\tdisk\tred\tunsafe\n' | ./bin/sasd-status-store --spool "$tmp/status" >/dev/null 2>&1; then
    echo "unsafe host accepted" >&2
    exit 1
fi
printf 'partial-host\tdisk\tgreen\tgood\n' > "$tmp/partial.tsv"
printf 'evil/host\tdisk\tred\tunsafe\n' >> "$tmp/partial.tsv"
if ./bin/sasd-status-store --spool "$tmp/status" --input "$tmp/partial.tsv" >/dev/null 2>&1; then
    echo "malformed batch accepted" >&2
    exit 1
fi
test ! -e "$tmp/status/partial-host.disk.status"
printf 'lab-host\tdisk\tgreen\twriter-one\n' | ./bin/sasd-status-store --spool "$tmp/status" >/dev/null &
writer_one=$!
printf 'lab-host\tdisk\tgreen\twriter-two\n' | ./bin/sasd-status-store --spool "$tmp/status" >/dev/null &
writer_two=$!
wait "$writer_one"
wait "$writer_two"
awk -F '\t' 'NF == 5 && $2 == "lab-host" && $3 == "disk"' "$tmp/status/lab-host.disk.status" >/dev/null
# Verify CRLF detection with a synthetic file; no host files are changed.
printf 'line with CRLF\r\n' > "$tmp/crlf-example"
if perl tests/check-eol.pl "$tmp/crlf-example" > "$tmp/line-endings-out" 2>&1; then
    echo "CRLF sample was not rejected" >&2
    exit 1
fi
grep -q 'CRLF or carriage return' "$tmp/line-endings-out"
echo "SASD smoke tests: PASS"
