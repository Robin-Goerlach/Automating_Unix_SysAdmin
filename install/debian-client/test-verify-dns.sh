#!/bin/sh
# No DNS traffic: all responses are synthetic text fixtures.
set -eu
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
tmp=$(mktemp -d); trap 'rm -rf -- "$tmp"' EXIT
cat > "$tmp/good" <<'DIG'
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 42
;; flags: qr rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1
;; QUESTION SECTION:
;node.lab.invalid. IN A

;; ANSWER SECTION:
node.lab.invalid. 60 IN A 192.0.2.40

;; Query time: 1 msec
;; SERVER: 192.0.2.53#53(192.0.2.53) (UDP)
DIG
run(){ perl "$here/verify-dns.pl" --fixture="$1" --server=192.0.2.53 --name=node.lab.invalid --expected=192.0.2.40; }
expect(){ rc=0; run "$1" > "$tmp/out" || rc=$?; [ "$rc" -eq "$2" ]; grep -qx "status$(printf '\t')$3" "$tmp/out"; }
expect "$tmp/good" 0 FIXTURE_MATCH
grep -qx 'scope[[:space:]]FIXTURE_ONLY' "$tmp/out"
sed 's/IN A 192.0.2.40/IN A 192.0.2.41/' "$tmp/good" > "$tmp/bad"; expect "$tmp/bad" 1 MISMATCH
sed 's/status: NOERROR/status: NXDOMAIN/' "$tmp/good" > "$tmp/bad"; expect "$tmp/bad" 1 MISMATCH
sed 's/status: NOERROR/status: SERVFAIL/' "$tmp/good" > "$tmp/bad"; expect "$tmp/bad" 1 MISMATCH
sed 's/ANSWER: 1/ANSWER: 2/' "$tmp/good" > "$tmp/bad"; expect "$tmp/bad" 1 MISMATCH
sed 's/60 IN A 192.0.2.40/60 IN CNAME other.lab.invalid./' "$tmp/good" > "$tmp/bad"; expect "$tmp/bad" 1 MISMATCH
sed 's/SERVER: 192.0.2.53/SERVER: 192.0.2.54/' "$tmp/good" > "$tmp/bad"; expect "$tmp/bad" 3 UNKNOWN
sed 's/flags: qr rd ra/flags: qr tc rd ra/' "$tmp/good" > "$tmp/bad"; expect "$tmp/bad" 3 UNKNOWN
sed 's/;node.lab.invalid. IN A/;other.lab.invalid. IN A/' "$tmp/good" > "$tmp/bad"; expect "$tmp/bad" 3 UNKNOWN
cat "$tmp/good" "$tmp/good" > "$tmp/bad"; expect "$tmp/bad" 3 UNKNOWN
: > "$tmp/bad"; expect "$tmp/bad" 3 UNKNOWN
rc=0; perl "$here/verify-dns.pl" --fixture="$tmp/good" --server=192.0.2.053 --name=node.lab.invalid --expected=192.0.2.40 > "$tmp/out" 2>&1 || rc=$?; [ "$rc" -eq 2 ]
rc=0; perl "$here/verify-dns.pl" --fixture="$tmp/good" --live --server=192.0.2.53 --name=node.lab.invalid --expected=192.0.2.40 > "$tmp/out" 2>&1 || rc=$?; [ "$rc" -eq 2 ]
echo 'DNS response fixture tests passed'
