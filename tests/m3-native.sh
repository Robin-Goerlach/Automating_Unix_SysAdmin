#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
require=0
while [ "$#" -gt 0 ]; do
    case "$1" in
        --require) require=1; shift ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
done
rrd=${RRDTOOL_BIN:-$(command -v rrdtool 2>/dev/null || true)}
mrtg=${MRTG_BIN:-$(command -v mrtg 2>/dev/null || true)}
if [ -z "$rrd" ] || [ -z "$mrtg" ]; then
    echo "M3 native integration: SKIPPED (set RRDTOOL_BIN and MRTG_BIN or install both)"
    [ "$require" -eq 1 ] && exit 3
    exit 0
fi
[ -x "$rrd" ] && [ -x "$mrtg" ] || { echo "native tools must be executable" >&2; exit 2; }
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT HUP INT TERM
export LANG=C LC_ALL=C
now=$(date +%s); now=$((now / 300 * 300)); start=$((now - 900)); t1=$((now - 600)); t2=$((now - 300))
"$rrd" --version | grep -q '^RRDtool '
"$rrd" create "$tmp/traffic.rrd" --start "$start" --step 300 \
    DS:in:COUNTER:600:0:U DS:out:COUNTER:600:0:U \
    RRA:AVERAGE:0.5:1:288 RRA:AVERAGE:0.5:12:168 RRA:MAX:0.5:12:168
"$rrd" update "$tmp/traffic.rrd" "$t1:120000:340000"
"$rrd" update "$tmp/traffic.rrd" "$t2:121000:341500"
"$rrd" fetch "$tmp/traffic.rrd" AVERAGE -s "$start" -e "$now" > "$tmp/fetch"
grep -q '3\.3333333333e+00' "$tmp/fetch"
"$rrd" graph "$tmp/traffic.png" --start "$start" --end "$now" DEF:in="$tmp/traffic.rrd":in:AVERAGE LINE2:in#00aa00:in >/dev/null
test -s "$tmp/traffic.png"
cat > "$tmp/mrtg.cfg" <<EOF
WorkDir: $tmp/work
Interval: 5
Target[sasd_lab]: \`$PWD/bin/sasd-mrtg-counter --input $PWD/fixtures/mrtg/ifcounters.tsv\`
MaxBytes[sasd_lab]: 1250000
Options[sasd_lab]: growright,nopercent
Title[sasd_lab]: SASD Lab Interface Counters
PageTop[sasd_lab]: <h1>SASD Lab Interface</h1>
EOF
mkdir "$tmp/work"
"$mrtg" "$tmp/mrtg.cfg" > "$tmp/mrtg.log" 2>&1
test -s "$tmp/work/sasd_lab.html"
test -s "$tmp/work/sasd_lab-day.png"
echo "M3 native integration: PASS rrdtool=$rrd mrtg=$mrtg"
