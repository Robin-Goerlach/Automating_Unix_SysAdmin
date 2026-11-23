#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
./bin/sasd-passwd-audit --input fixtures/passwd/clean.txt > "$tmp/passwd"
grep -q 'warnings=0 invalid=0' "$tmp/passwd"
if ./bin/sasd-passwd-audit --input fixtures/passwd/uid0.txt > "$tmp/uid0"; then
    echo "unexpected root duplicate accepted" >&2
    exit 1
fi
grep -q 'unexpected uid 0' "$tmp/uid0"
./bin/sasd-syslog-count --input fixtures/syslog/classic.log > "$tmp/syslog"
grep -q "$(printf 'cron\t2')" "$tmp/syslog"
grep -q "$(printf '_unparsed\t1')" "$tmp/syslog"
./bin/sasd-ntp-sources --input fixtures/ntp/ntp.conf > "$tmp/ntp"
grep -q "$(printf 'TOTAL\t2')" "$tmp/ntp"
./bin/sasd-cron-inspect --input fixtures/cron/user.crontab > "$tmp/cron"
grep -q 'jobs=2' "$tmp/cron"
printf '60 * * * * /bin/true\n' > "$tmp/badcron"
if ./bin/sasd-cron-inspect --input "$tmp/badcron" > "$tmp/bad"; then
    echo "out-of-range cron accepted" >&2
    exit 1
fi
grep -q '^INVALID' "$tmp/bad"
echo "Classic Unix checks: PASS"
