#!/bin/sh
# Complete offline M2 enrollment demonstration. No network, root, or real host changes.
set -eu
cd "$(dirname "$0")/.."
lab=$(mktemp -d)
trap 'rm -rf "$lab"' EXIT HUP INT TERM
server="$lab/server"
client="$lab/client"
install/install-monitoring-server.sh --prefix "$server" --config site/monitoring.conf --apply >/dev/null
install/install-sasd-client.sh --prefix "$client" --host m2.lab.invalid --role web --profile web --expires-at 2000000000 --apply >/dev/null
"$server/bin/sasd-enrollment" --dir "$server/var/enrollment" --action import-request --request "$client/var/enrollment.request" >/dev/null
"$server/bin/sasd-enrollment" --dir "$server/var/enrollment" --action approve --host m2.lab.invalid --operator admin --at 1000 >/dev/null
printf 'm2.lab.invalid\tdisk\tgreen\tdisk healthy\nm2.lab.invalid\thttp\tgreen\tservice healthy\n' > "$lab/status.tsv"
"$client/bin/sasd-node-status" --host m2.lab.invalid --key "$client/etc/identity" --sequence 1 --sent-at 1000 --input "$lab/status.tsv" --out "$lab/payload" >/dev/null
"$server/bin/sasd-monitor-auth-import" --config "$server/etc/sasd-monitor.conf" --input "$lab/payload" --signature "$lab/payload.sig" --now 1100 >/dev/null
"$server/bin/sasd-monitor-cycle" --config "$server/etc/sasd-monitor.conf" --now 1100 > "$lab/cycle"
"$server/bin/sasd-monitor-report" --config "$server/etc/sasd-monitor.conf" --out "$lab/report.html"
grep -q 'm2.lab.invalid' "$lab/report.html"
grep -q 'service healthy' "$lab/report.html"
echo "M2 enrollment laboratory: PASS"
