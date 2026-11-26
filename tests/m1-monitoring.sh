#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

./bin/sasd-monitor-config --config site/monitoring.conf --check > "$tmp/config"
grep -q '^config=OK$' "$tmp/config"
grep -q 'rrdtool=SKIPPED' "$tmp/config"
./bin/sasd-monitor-hosts --config site/monitoring.conf --host web.lab.invalid > "$tmp/host"
grep -q '^web.lab.invalid' "$tmp/host"
./bin/sasd-monitor-mrtg --config site/monitoring.conf --out "$tmp/mrtg.cfg"
grep -q 'Target\[web_lab_invalid_interface\]' "$tmp/mrtg.cfg"
printf 'web.lab.invalid\tdisabled\toperator\n' > "$tmp/host-state.tsv"
./bin/sasd-monitor-mrtg --config site/monitoring.conf --host-state "$tmp/host-state.tsv" --out "$tmp/mrtg-disabled.cfg"
if grep -q 'Target\[web_lab_invalid_interface\]' "$tmp/mrtg-disabled.cfg"; then
    echo "disabled host was emitted to MRTG" >&2; exit 1
fi
grep -q 'Target\[cfg_lab_invalid_interface\]' "$tmp/mrtg-disabled.cfg"
printf 'cfg.lab.invalid\tenabled\toperator\ncfg.lab.invalid\tenabled\tduplicate\n' > "$tmp/duplicate-state.tsv"
if ./bin/sasd-monitor-mrtg --config site/monitoring.conf --host-state "$tmp/duplicate-state.tsv" > "$tmp/duplicate-state-error" 2>&1; then
    echo "duplicate MRTG state accepted" >&2; exit 1
fi
grep -q 'duplicate host state record' "$tmp/duplicate-state-error"
cp site/hosts.tsv "$tmp/collision-hosts.tsv"
printf 'cfg_lab.invalid\t192.0.2.40\tunix\tweb\tlab\tweb\n' >> "$tmp/collision-hosts.tsv"
cp site/roles.tsv site/checks.tsv "$tmp/"
cp site/monitoring.conf "$tmp/collision.conf"
sed -i 's#inventory=hosts.tsv#inventory=collision-hosts.tsv#' "$tmp/collision.conf"
if ./bin/sasd-monitor-mrtg --config "$tmp/collision.conf" > "$tmp/collision-error" 2>&1; then
    echo "duplicate MRTG target id accepted" >&2; exit 1
fi
grep -q 'duplicate MRTG target id' "$tmp/collision-error"
if ./bin/sasd-monitor-mrtg --config site/monitoring.conf --out "$tmp/mrtg.cfg" > "$tmp/mrtg-error" 2>&1; then
    echo "MRTG output overwrite was not rejected" >&2; exit 1
fi
if ./bin/sasd-monitor-mrtg --config site/monitoring.conf --out site/hosts.tsv --force > "$tmp/mrtg-input-overwrite" 2>&1; then
    echo "MRTG input overwrite was accepted" >&2; exit 1
fi
grep -q 'output path overlaps an input file' "$tmp/mrtg-input-overwrite"
if ./bin/sasd-monitor-mrtg --config site/monitoring.conf --host-state "$tmp/host-state.tsv" --out "$tmp/host-state.tsv" --force > "$tmp/host-state-output-error" 2>&1; then
    echo "MRTG host-state overwrite was accepted" >&2
    exit 1
fi
grep -q 'output path overlaps an input file' "$tmp/host-state-output-error"

prefix="$tmp/install"
./install/install-monitoring-server.sh --prefix "$prefix" --config site/monitoring.conf --dry-run > "$tmp/dry"
test ! -e "$prefix"
./install/install-monitoring-server.sh --prefix "$prefix" --config site/monitoring.conf --apply > "$tmp/apply.log"
printf '# local operator note\n' >> "$prefix/etc/sasd-monitor.conf"
./install/install-monitoring-server.sh --prefix "$prefix" --config site/monitoring.conf --apply > "$tmp/reinstall"
grep -q 'local operator note' "$prefix/etc/sasd-monitor.conf"
if ./install/install-monitoring-server.sh --prefix /etc/sasd-monitor-lab-test --config site/monitoring.conf --apply > "$tmp/unsafe-prefix" 2>&1; then
    echo "unsafe system prefix accepted" >&2
fi
ln -s "$tmp/real-prefix" "$tmp/link-prefix"
if ./install/install-monitoring-server.sh --prefix "$tmp/link-prefix" --config site/monitoring.conf --apply > "$tmp/link-error" 2>&1; then
    echo "symlink prefix accepted" >&2; exit 1
fi

printf 'web.lab.invalid\tdisk\tgreen\tgood\n' > "$tmp/good.tsv"
"$prefix/bin/sasd-monitor-import" --config "$prefix/etc/sasd-monitor.conf" --input "$tmp/good.tsv" --received-at 100 --source test > "$tmp/import"
if "$prefix/bin/sasd-monitor-import" --config "$prefix/etc/sasd-monitor.conf" --input "$tmp/good.tsv" --received-at 90 --source test > "$tmp/old-error" 2>&1; then
    echo "older observation replaced newer observation" >&2; exit 1
fi
grep -q 'older observation' "$tmp/old-error"
"$prefix/bin/sasd-monitor-cycle" --config "$prefix/etc/sasd-monitor.conf" --now 1100 > "$tmp/stale-cycle"
grep -q 'web.lab.invalid	disk	green	purple' "$prefix/var/status/state.tsv"
"$prefix/bin/sasd-monitor-report" --config "$prefix/etc/sasd-monitor.conf" --out "$tmp/stale.html"
grep -q 'class="purple"' "$tmp/stale.html"

printf 'unknown.lab.invalid\tdisk\tgreen\tbad host\n' > "$tmp/unknown.tsv"
if "$prefix/bin/sasd-monitor-import" --config "$prefix/etc/sasd-monitor.conf" --input "$tmp/unknown.tsv" > "$tmp/unknown-error" 2>&1; then
    echo "unknown host accepted" >&2; exit 1
fi
grep -q 'unknown host' "$tmp/unknown-error"
printf 'web.lab.invalid\tdisk\tgreen\ttoo\tmany\n' > "$tmp/malformed.tsv"
if "$prefix/bin/sasd-monitor-import" --config "$prefix/etc/sasd-monitor.conf" --input "$tmp/malformed.tsv" > "$tmp/malformed-error" 2>&1; then
    echo "malformed status accepted" >&2; exit 1
fi
grep -q 'four fields' "$tmp/malformed-error"

printf 'web.lab.invalid\thttp\tred\t<tag>\n' > "$tmp/escaped.tsv"
"$prefix/bin/sasd-monitor-import" --config "$prefix/etc/sasd-monitor.conf" --input "$tmp/escaped.tsv" --received-at 1200 --source test >/dev/null
"$prefix/bin/sasd-monitor-cycle" --config "$prefix/etc/sasd-monitor.conf" --now 1201 >/dev/null
"$prefix/bin/sasd-monitor-report" --config "$prefix/etc/sasd-monitor.conf" --out "$tmp/escaped.html"
grep -q '&lt;tag&gt;' "$tmp/escaped.html"
grep -q 'web.lab.invalid.*http.*red.*red' "$prefix/var/status/state.tsv"
grep -q 'class="red"' "$tmp/escaped.html"

cp site/hosts.tsv site/roles.tsv site/checks.tsv "$tmp/"
sed 's/$/\r/' site/monitoring.conf > "$tmp/crlf.conf"
./bin/sasd-monitor-config --config "$tmp/crlf.conf" --check > "$tmp/crlf-config"
grep -q '^config=OK$' "$tmp/crlf-config"
if printf 'web.lab.invalid\tdisk\tgreen\tunsafe\n' | "$prefix/bin/sasd-monitor-import" --config "$prefix/etc/sasd-monitor.conf" --received-at 1300 --source bad/source > "$tmp/source-error" 2>&1; then
    echo "unsafe source accepted" >&2; exit 1
fi
if printf 'web.lab.invalid\tdisk\tgreen\tunsafe\n' | "$prefix/bin/sasd-monitor-import" --config "$prefix/etc/sasd-monitor.conf" --received-at 1300 --source ssh > "$tmp/reserved-source-error" 2>&1; then
    echo "reserved authenticated source accepted" >&2; exit 1
fi
grep -q 'reserved source' "$tmp/reserved-source-error"
echo "M1 monitoring server: PASS"
