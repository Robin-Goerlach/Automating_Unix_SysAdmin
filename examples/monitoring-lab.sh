#!/bin/sh
# Complete offline M1 demonstration. No network, root, or real host changes.
set -eu
cd "$(dirname "$0")/.."
lab=$(mktemp -d)
trap 'rm -rf "$lab"' EXIT HUP INT TERM
prefix="$lab/install"
install/install-monitoring-server.sh --prefix "$prefix" --config site/monitoring.conf --apply > "$lab/install.log"
test -f "$prefix/etc/sasd-monitor.conf"

cat > "$lab/healthy.tsv" <<'EOF'
cfg.lab.invalid	config-audit	green	configuration matches
web.lab.invalid	config-audit	green	configuration matches
web.lab.invalid	disk	green	filesystem within limits
web.lab.invalid	http	green	web check passed
mail.lab.invalid	disk	yellow	filesystem warning
mail.lab.invalid	smtp	green	mail check passed
mon.lab.invalid	disk	green	filesystem within limits
mon.lab.invalid	monitoring	green	monitoring self-check passed
EOF
"$prefix/bin/sasd-monitor-import" --config "$prefix/etc/sasd-monitor.conf" --input "$lab/healthy.tsv" --received-at 1000 --source lab
"$prefix/bin/sasd-monitor-cycle" --config "$prefix/etc/sasd-monitor.conf" --now 1100 > "$lab/cycle-healthy.tsv"
"$prefix/bin/sasd-monitor-report" --config "$prefix/etc/sasd-monitor.conf" --out "$lab/healthy.html"
grep -q 'class="green"' "$lab/healthy.html"
grep -q 'class="purple"' "$lab/healthy.html"

printf 'web.lab.invalid\tdisk\tyellow\tdisk warning from lab\n' > "$lab/warning.tsv"
"$prefix/bin/sasd-monitor-import" --config "$prefix/etc/sasd-monitor.conf" --input "$lab/warning.tsv" --received-at 1200 --source lab
"$prefix/bin/sasd-monitor-cycle" --config "$prefix/etc/sasd-monitor.conf" --now 1250 > "$lab/cycle-warning.tsv"
grep -q 'web.lab.invalid	disk	yellow' "$prefix/var/status/state.tsv"

printf 'web.lab.invalid\tdisk\tgreen\tdisk recovered in lab\n' > "$lab/recovery.tsv"
"$prefix/bin/sasd-monitor-import" --config "$prefix/etc/sasd-monitor.conf" --input "$lab/recovery.tsv" --received-at 1300 --source lab
"$prefix/bin/sasd-monitor-cycle" --config "$prefix/etc/sasd-monitor.conf" --now 1350 > "$lab/cycle-recovery.tsv"
"$prefix/bin/sasd-monitor-report" --config "$prefix/etc/sasd-monitor.conf" --out "$lab/recovery.html"
grep -q 'web.lab.invalid	disk	green' "$prefix/var/status/state.tsv"
grep -q 'yellow	green' "$prefix/var/history/events.tsv"
grep -q 'disk recovered in lab' "$lab/recovery.html"
echo "M1 monitoring laboratory: PASS"
