#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT HUP INT TERM
prefix="$tmp/server"
install/install-monitoring-server.sh --prefix "$prefix" --config site/monitoring.conf --apply >/dev/null
printf 'web.lab.invalid\tdisk\tred\tmaintenance fixture\n' > "$tmp/status.tsv"
"$prefix/bin/sasd-monitor-import" --config "$prefix/etc/sasd-monitor.conf" --input "$tmp/status.tsv" --received-at 900 --source test >/dev/null
"$prefix/bin/sasd-monitor-control" --config "$prefix/etc/sasd-monitor.conf" --action maintenance-add --host web.lab.invalid --check disk --until 2000000000 --operator admin --reason planned >/dev/null
"$prefix/bin/sasd-monitor-control" --config "$prefix/etc/sasd-monitor.conf" --action acknowledge --host web.lab.invalid --check disk --until 2000000000 --operator admin --reason reviewed >/dev/null
"$prefix/bin/sasd-monitor-cycle" --config "$prefix/etc/sasd-monitor.conf" --now 1000 > "$tmp/cycle"
grep -q 'web.lab.invalid.*disk.*\[acknowledged until 2000000000\].*\[maintenance until 2000000000\]' "$tmp/cycle"
"$prefix/bin/sasd-monitor-control" --config "$prefix/etc/sasd-monitor.conf" --action list > "$tmp/list"
grep -q '^maintenance' "$tmp/list"
grep -q '^acknowledgement' "$tmp/list"
"$prefix/bin/sasd-monitor-control" --config "$prefix/etc/sasd-monitor.conf" --action maintenance-clear --host web.lab.invalid --check disk --operator admin --reason finished >/dev/null
"$prefix/bin/sasd-monitor-control" --config "$prefix/etc/sasd-monitor.conf" --action acknowledgement-clear --host web.lab.invalid --check disk --operator admin --reason finished >/dev/null
if "$prefix/bin/sasd-monitor-control" --config "$prefix/etc/sasd-monitor.conf" --action maintenance-add --host web.lab.invalid --check disk --until 1 --operator admin --reason expired >/dev/null 2>&1; then
    echo "expired maintenance accepted" >&2; exit 1
fi
echo "M4 maintenance/acknowledgement: PASS"
