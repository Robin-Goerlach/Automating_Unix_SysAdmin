#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

server="$tmp/server"
accepted="$tmp/accepted"
rejected="$tmp/rejected"
install/install-monitoring-server.sh --prefix "$server" --config site/monitoring.conf --apply > "$tmp/server.log"
install/install-sasd-client.sh --prefix "$accepted" --host enrolled.lab.invalid --role web --profile web --expires-at 2000000000 --apply > "$tmp/accepted.log"
install/install-sasd-client.sh --prefix "$rejected" --host denied.lab.invalid --role web --profile web --expires-at 2000000000 --apply > "$tmp/rejected.log"

"$server/bin/sasd-enrollment" --dir "$server/var/enrollment" --action import-request --request "$accepted/var/enrollment.request"
"$server/bin/sasd-enrollment" --dir "$server/var/enrollment" --action import-request --request "$rejected/var/enrollment.request"
"$server/bin/sasd-enrollment" --dir "$server/var/enrollment" --action approve --host enrolled.lab.invalid --operator admin --at 1000
"$server/bin/sasd-enrollment" --dir "$server/var/enrollment" --action reject --host denied.lab.invalid --operator admin --at 1000 --reason policy

printf 'enrolled.lab.invalid\tdisk\tgreen\tinitial healthy state\nenrolled.lab.invalid\thttp\tgreen\tservice healthy\n' > "$tmp/healthy.tsv"
"$accepted/bin/sasd-node-status" --host enrolled.lab.invalid --key "$accepted/etc/identity" --sequence 1 --sent-at 1000 --input "$tmp/healthy.tsv" --out "$tmp/healthy.payload"
"$server/bin/sasd-monitor-auth-import" --config "$server/etc/sasd-monitor.conf" --input "$tmp/healthy.payload" --signature "$tmp/healthy.payload.sig" --now 1100
"$server/bin/sasd-monitor-cycle" --config "$server/etc/sasd-monitor.conf" --now 1100 > "$tmp/healthy.cycle"
"$server/bin/sasd-monitor-report" --config "$server/etc/sasd-monitor.conf" --out "$tmp/healthy.html"
grep -q 'enrolled.lab.invalid' "$tmp/healthy.html"
grep -q 'initial healthy state' "$tmp/healthy.html"

if "$server/bin/sasd-monitor-auth-import" --config "$server/etc/sasd-monitor.conf" --input "$tmp/healthy.payload" --signature "$tmp/healthy.payload.sig" --now 1101 > "$tmp/replay-error" 2>&1; then
    echo "replayed payload accepted" >&2; exit 1
fi
grep -q 'replayed' "$tmp/replay-error"

sed -e 's/SASD-AUTH-1\tenrolled.lab.invalid\t1\t/SASD-AUTH-1\tenrolled.lab.invalid\t2\t/' -e 's/initial healthy state/tampered state/' "$tmp/healthy.payload" > "$tmp/tampered.payload"
if "$server/bin/sasd-monitor-auth-import" --config "$server/etc/sasd-monitor.conf" --input "$tmp/tampered.payload" --signature "$tmp/healthy.payload.sig" --now 1101 > "$tmp/tamper-error" 2>&1; then
    echo "tampered payload accepted" >&2; exit 1
fi
grep -qi 'signature' "$tmp/tamper-error"

printf 'enrolled.lab.invalid\tdisk\tyellow\tcapacity warning\nenrolled.lab.invalid\thttp\tgreen\tservice healthy\n' > "$tmp/warning.tsv"
"$accepted/bin/sasd-node-status" --host enrolled.lab.invalid --key "$accepted/etc/identity" --sequence 2 --sent-at 1200 --input "$tmp/warning.tsv" --out "$tmp/warning.payload"
"$server/bin/sasd-monitor-auth-import" --config "$server/etc/sasd-monitor.conf" --input "$tmp/warning.payload" --signature "$tmp/warning.payload.sig" --now 1250
"$server/bin/sasd-monitor-cycle" --config "$server/etc/sasd-monitor.conf" --now 1250 > "$tmp/warning.cycle"
grep -q 'enrolled.lab.invalid.*disk.*yellow' "$tmp/warning.cycle"

printf 'enrolled.lab.invalid\tdisk\tred\tcapacity critical\nenrolled.lab.invalid\thttp\tgreen\tservice healthy\n' > "$tmp/critical.tsv"
"$accepted/bin/sasd-node-status" --host enrolled.lab.invalid --key "$accepted/etc/identity" --sequence 3 --sent-at 1300 --input "$tmp/critical.tsv" --out "$tmp/critical.payload"
"$server/bin/sasd-monitor-auth-import" --config "$server/etc/sasd-monitor.conf" --input "$tmp/critical.payload" --signature "$tmp/critical.payload.sig" --now 1350
"$server/bin/sasd-monitor-cycle" --config "$server/etc/sasd-monitor.conf" --now 1350 > "$tmp/critical.cycle"
grep -q 'enrolled.lab.invalid.*disk.*red' "$tmp/critical.cycle"
"$server/bin/sasd-monitor-cycle" --config "$server/etc/sasd-monitor.conf" --now 2300 > "$tmp/stale.cycle"
grep -q 'enrolled.lab.invalid.*disk.*purple' "$tmp/stale.cycle"

printf 'enrolled.lab.invalid\tdisk\tgreen\trecovered\nenrolled.lab.invalid\thttp\tgreen\tservice healthy\n' > "$tmp/recovery.tsv"
"$accepted/bin/sasd-node-status" --host enrolled.lab.invalid --key "$accepted/etc/identity" --sequence 4 --sent-at 2400 --input "$tmp/recovery.tsv" --out "$tmp/recovery.payload"
"$server/bin/sasd-monitor-auth-import" --config "$server/etc/sasd-monitor.conf" --input "$tmp/recovery.payload" --signature "$tmp/recovery.payload.sig" --now 2450
"$server/bin/sasd-monitor-cycle" --config "$server/etc/sasd-monitor.conf" --now 2450 > "$tmp/recovery.cycle"
grep -q 'enrolled.lab.invalid.*disk.*green' "$tmp/recovery.cycle"

printf 'denied.lab.invalid\tdisk\tgreen\trejected client\n' > "$tmp/rejected.tsv"
"$rejected/bin/sasd-node-status" --host denied.lab.invalid --key "$rejected/etc/identity" --sequence 1 --sent-at 1000 --input "$tmp/rejected.tsv" --out "$tmp/rejected.payload"
if "$server/bin/sasd-monitor-auth-import" --config "$server/etc/sasd-monitor.conf" --input "$tmp/rejected.payload" --signature "$tmp/rejected.payload.sig" --now 1101 > "$tmp/rejected-error" 2>&1; then
    echo "rejected host payload accepted" >&2; exit 1
fi

"$server/bin/sasd-enrollment" --dir "$server/var/enrollment" --action disable --host enrolled.lab.invalid --operator admin --at 1200
"$server/bin/sasd-monitor-cycle" --config "$server/etc/sasd-monitor.conf" --now 1200 > "$tmp/disabled.cycle"
grep -q 'enrolled.lab.invalid.*purple.*enrollment disabled' "$tmp/disabled.cycle"
if "$server/bin/sasd-monitor-auth-import" --config "$server/etc/sasd-monitor.conf" --input "$tmp/recovery.payload" --signature "$tmp/recovery.payload.sig" --now 2451 > "$tmp/disabled-error" 2>&1; then
    echo "disabled host accepted" >&2; exit 1
fi
grep -q 'not active' "$tmp/disabled-error"

"$server/bin/sasd-enrollment" --dir "$server/var/enrollment" --action status --host denied.lab.invalid > "$tmp/denied-status"
grep -q 'denied.lab.invalid.*rejected' "$tmp/denied-status"
echo "M2 enrollment and authenticated import: PASS"
