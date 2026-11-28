#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT HUP INT TERM

configure() {
    hosts=$1
    shift
    bin/sasd-config-ganglia --hosts "$hosts" --roles site/roles.tsv "$@"
}
configure site/hosts.tsv --gmond-out "$tmp/gmond.conf" --gmetad-out "$tmp/gmetad.conf"
grep -q 'name = "default"' "$tmp/gmond.conf"
grep -q '^# data_source "default" unresolved$' "$tmp/gmetad.conf"

cat > "$tmp/hosts.tsv" <<'INVENTORY'
web.lab.invalid	192.0.2.11	unix	web	admin,ganglia-west	web
mail.lab.invalid	192.0.2.12	unix	mail	lab,ganglia-east	mail
cfg.lab.invalid	192.0.2.10	unix	config	lab,ganglia-east	config
mon.lab.invalid	192.0.2.13	unix	monitoring	lab,ganglia-west	monitoring
INVENTORY
printf 'cfg.lab.invalid\tdisabled\toperator\nmon.lab.invalid\tremoved\toperator\n' > "$tmp/state.tsv"
configure "$tmp/hosts.tsv" --state "$tmp/state.tsv" --gmond-out "$tmp/multi.conf" --gmetad-out "$tmp/aggregate.conf"
test ! -e "$tmp/multi.conf"
for side in east west; do
    file="$tmp/multi.ganglia-$side.conf"
    [ "$(grep -c '^cluster {' "$file")" -eq 1 ]
    grep -q "name = \"ganglia-$side\"" "$file"
    grep -q "^# data_source \"ganglia-$side\" unresolved$" "$tmp/aggregate.conf"
done
grep -q '^# Members: web.lab.invalid$' "$tmp/multi.ganglia-west.conf"
grep -q '^# Members: mail.lab.invalid$' "$tmp/multi.ganglia-east.conf"
if grep -Eq '^(data_source|udp_.*channel|tcp_.*channel)' "$tmp/"*.conf; then
    echo 'unresolved topology emitted an active transport or source' >&2; exit 1
fi

sed 's/admin,ganglia-west/admin,ganglia-west,ganglia-east/' "$tmp/hosts.tsv" > "$tmp/ambiguous.tsv"
for case in ambiguous missing-state collision symlink; do
    case "$case" in
        ambiguous) set -- "$tmp/ambiguous.tsv" --gmond-out "$tmp/rejected.conf" --gmetad-out "$tmp/rejected-metad.conf" ;;
        missing-state) set -- "$tmp/hosts.tsv" --state "$tmp/missing.tsv" --gmond-out "$tmp/rejected.conf" --gmetad-out "$tmp/rejected-metad.conf" ;;
        collision) set -- "$tmp/hosts.tsv" --gmond-out "$tmp/rejected.conf" --gmetad-out "$tmp/rejected.ganglia-west.conf" ;;
        symlink)
            ln -s "$tmp" "$tmp/alias"
            set -- "$tmp/hosts.tsv" --gmond-out "$tmp/rejected.conf" --gmetad-out "$tmp/alias/rejected-metad.conf" ;;
    esac
    if configure "$@" > "$tmp/config-error" 2>&1; then
        echo "invalid Ganglia topology accepted: $case" >&2; exit 1
    fi
    test ! -e "$tmp/rejected.ganglia-east.conf"
done

mkdir -m 0700 "$tmp/target"
deploy() {
    bin/sasd-config-deploy --hosts "$tmp/hosts.tsv" --roles site/roles.tsv \
        --checks site/checks.tsv --services site/services.tsv --state "$tmp/state.tsv" \
        --staging "$tmp/stage" --target "$tmp/target" --plan "$tmp/plan" "$@"
}
deploy --prepare > "$tmp/prepare"
for side in east west; do
    grep -q "^ganglia/gmond.ganglia-$side.conf$(printf '\t')" "$tmp/stage/MANIFEST.tsv"
done
deploy --apply > "$tmp/apply"
test -f "$tmp/target/ganglia/gmond.ganglia-east.conf"
test -f "$tmp/target/ganglia/gmond.ganglia-west.conf"
deploy --dry-run | grep -q 'changes=0 status=DRY-RUN'

metric() {
    bin/sasd-ganglia-metric --hosts "$tmp/hosts.tsv" --roles site/roles.tsv \
        --state "$tmp/state.tsv" --now 1700000900 --input "$1"
}
cat > "$tmp/valid.tsv" <<'METRICS'
web.lab.invalid	ganglia-west	1699999999	cpu	12.5	percent	gauge
web.lab.invalid	ganglia-west	1700000000	cpu	100	percent	gauge
web.lab.invalid	ganglia-west	1700000901	cpu	0	percent	gauge
web.lab.invalid	ganglia-west	1700000900	mem	32768	bytes	gauge
web.lab.invalid	ganglia-west	1700000900	load	1.25	count	gauge
mail.lab.invalid	ganglia-east	1700000900	net_rx	999999999999999	bytes	counter
mail.lab.invalid	ganglia-east	1700000900	net_tx	0	bytes	counter
METRICS
metric "$tmp/valid.tsv" > "$tmp/out"
awk -F '\t' 'NF != 9 || $9 != "FIXTURE" { exit 1 }
    NR == 1 || NR == 3 { if ($1 != "UNKNOWN") exit 1; next }
    $1 != "OK" { exit 1 }
    END { if (NR != 7) exit 1 }' "$tmp/out"

reject_batch() {
    if metric "$1" > "$tmp/bad-out" 2> "$tmp/metric-error"; then
        echo "invalid Ganglia batch accepted: $1" >&2; exit 1
    fi
    test ! -s "$tmp/bad-out"
    grep -q "$2" "$tmp/metric-error"
}
for case in 'cpu 900 percent gauge' 'cpu 12 bytes gauge' 'cpu 12 percent counter' \
    'cpu NaN percent gauge' 'cpu Inf percent gauge' 'cpu -1 percent gauge' \
    'net_rx 12 bytes/s counter' 'net_rx 12 bytes gauge' \
    'net_rx 1000000000000000 bytes counter' 'mem 1.2 bytes gauge'; do
    set -- $case
    cp "$tmp/valid.tsv" "$tmp/bad.tsv"
    printf 'web.lab.invalid\tganglia-west\t1700000902\t%s\t%s\t%s\t%s\n' "$@" >> "$tmp/bad.tsv"
    reject_batch "$tmp/bad.tsv" 'invalid metric'
done
for case in 'other.lab.invalid ganglia-west' 'web.lab.invalid other' 'web.lab.invalid ganglia-east' \
    'cfg.lab.invalid ganglia-east' 'mon.lab.invalid ganglia-west'; do
    set -- $case
    printf '%s\t%s\t1700000900\tcpu\t12.5\tpercent\tgauge\n' "$@" > "$tmp/bad.tsv"
    reject_batch "$tmp/bad.tsv" 'invalid metric identity'
done
head -n 2 "$tmp/valid.tsv" > "$tmp/bad.tsv"
sed -n '2p' "$tmp/valid.tsv" >> "$tmp/bad.tsv"
reject_batch "$tmp/bad.tsv" 'duplicate metric observation'
sed -n '2p;3p;4p' "$tmp/valid.tsv" > "$tmp/bad.tsv"
head -n 1 "$tmp/valid.tsv" >> "$tmp/bad.tsv"
reject_batch "$tmp/bad.tsv" 'out of order'
cp "$tmp/valid.tsv" "$tmp/bad.tsv"
printf '# control\000\n' >> "$tmp/bad.tsv"
reject_batch "$tmp/bad.tsv" 'invalid metric control byte'
: > "$tmp/bad.tsv"
reject_batch "$tmp/bad.tsv" 'no metric observations'
head -c 2049 /dev/zero > "$tmp/bad.tsv"
reject_batch "$tmp/bad.tsv" 'line too long'
head -c 262145 /dev/zero > "$tmp/bad.tsv"
reject_batch "$tmp/bad.tsv" 'exceeds byte limit'
awk 'BEGIN { for (i = 1; i <= 4097; i++) printf "web.lab.invalid\tganglia-west\t%d\tcpu\t1\tpercent\tgauge\n", i }' > "$tmp/bad.tsv"
reject_batch "$tmp/bad.tsv" 'too many metric observations'
echo 'Ganglia offline candidate, multicluster deployment and atomic metric validation: PASS'
