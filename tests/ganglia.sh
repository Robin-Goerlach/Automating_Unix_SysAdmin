#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT HUP INT TERM
bin/sasd-config-ganglia --hosts site/hosts.tsv --roles site/roles.tsv \
    --gmond-out "$tmp/gmond.conf" --gmetad-out "$tmp/gmetad.conf"
grep -q 'cluster {' "$tmp/gmond.conf"
grep -q 'mcast_join = 239.2.11.71' "$tmp/gmond.conf"
grep -q 'data_source' "$tmp/gmetad.conf"
printf '# hostname\taddress\tos-family\trole\tgroups\tprofile\nweb.lab.invalid\t192.0.2.11\tunix\tweb\tadmin,ganglia-west\tweb\nmail.lab.invalid\t192.0.2.12\tunix\tmail\tlab,ganglia-east\tmail\n' > "$tmp/cluster-hosts.tsv"
bin/sasd-config-ganglia --hosts "$tmp/cluster-hosts.tsv" --roles site/roles.tsv \
    --gmond-out "$tmp/multi-gmond.conf" --gmetad-out "$tmp/multi-gmetad.conf"
grep -q 'name = "ganglia-east"' "$tmp/multi-gmond.conf"
grep -q 'name = "ganglia-west"' "$tmp/multi-gmond.conf"
! grep -q 'name = "admin"' "$tmp/multi-gmond.conf"
! grep -q 'name = "lab"' "$tmp/multi-gmond.conf"
grep -q 'data_source "ganglia-east"' "$tmp/multi-gmetad.conf"
grep -q 'data_source "ganglia-west"' "$tmp/multi-gmetad.conf"
printf 'web.lab.invalid\tlab\t1700000000\tcpu\t12.5\tpercent\tgauge\n' > "$tmp/metrics.tsv"
bin/sasd-ganglia-metric --input "$tmp/metrics.tsv" --now 1700000001 > "$tmp/out"
grep -q '^OK	web.lab.invalid	lab	1700000000	cpu	12.5	percent	gauge$' "$tmp/out"
printf 'web.lab.invalid\tlab\t1700000000\tbogus\t1\tcount\tgauge\n' > "$tmp/bad.tsv"
if bin/sasd-ganglia-metric --input "$tmp/bad.tsv" >/dev/null 2>&1; then
    echo 'unknown Ganglia metric accepted' >&2; exit 1
fi
printf 'web.lab.invalid\tlab\t1700000000\tcpu\t12.5\tpercent\tgauge\nweb.lab.invalid\tlab\t1699999999\tcpu\t12.5\tpercent\tgauge\n' > "$tmp/order.tsv"
if bin/sasd-ganglia-metric --input "$tmp/order.tsv" >/dev/null 2>&1; then
    echo 'out-of-order Ganglia metric accepted' >&2; exit 1
fi
echo 'Ganglia offline candidate and metric validation: PASS'
