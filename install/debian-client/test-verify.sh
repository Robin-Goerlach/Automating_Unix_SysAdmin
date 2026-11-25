#!/bin/sh
set -eu
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir -p "$tmp/root/etc"
printf 'dns1=192.0.2.53\ndns2=192.0.2.54\nsearch=lab.invalid\n' > "$tmp/site"
printf 'node\n' > "$tmp/root/etc/hostname"
printf '127.0.0.1 localhost\n127.0.1.1 node.lab.invalid node\n::1 localhost ip6-localhost\n192.0.2.22 other.lab.invalid other\n' > "$tmp/root/etc/hosts"
printf 'nameserver 192.0.2.53\nnameserver 192.0.2.54\nsearch lab.invalid\n' > "$tmp/root/etc/resolv.conf"
run(){ "$here/verify-baseline.sh" --root="$tmp/root" --hostname=node.lab.invalid --site="$tmp/site"; }
(cd "$tmp/root" && sha256sum etc/*) > "$tmp/before"
run > "$tmp/out"
[ "$(grep -c 'OK$' "$tmp/out")" -eq 3 ]
(cd "$tmp/root" && sha256sum -c "$tmp/before")
printf 'wrong\n' > "$tmp/root/etc/hostname"
rc=0; run > "$tmp/out" || rc=$?; [ "$rc" -eq 1 ]; grep -q 'hostname.*DRIFT' "$tmp/out"
printf '192.0.2.23 node.lab.invalid node\n' >> "$tmp/root/etc/hosts"
rc=0; run > "$tmp/out" || rc=$?; [ "$rc" -eq 1 ]; grep -q 'hosts.*DRIFT' "$tmp/out"
rm "$tmp/root/etc/resolv.conf"; ln -s /dev/null "$tmp/root/etc/resolv.conf"
rc=0; run > "$tmp/out" || rc=$?; [ "$rc" -eq 2 ]; grep -q 'resolver.*UNKNOWN' "$tmp/out"
printf 'dns1=999.0.0.1\nsearch=lab.invalid\n' > "$tmp/site"
rc=0; run > "$tmp/out" 2>&1 || rc=$?; [ "$rc" -eq 2 ]
echo 'Baseline verification tests passed'
