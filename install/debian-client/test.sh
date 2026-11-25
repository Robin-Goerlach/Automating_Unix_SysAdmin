#!/bin/sh
set -eu
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT HUP INT TERM
for f in "$here"/tasks/* "$here"/lib/task.sh "$here"/*.sh; do sh -n "$f"; done
count=$(awk 'END {print NR-1}' "$here/checklist.tsv")
[ "$("$here/install-client.sh" --list | wc -l)" -eq "$count" ]
rc=0
"$here/install-client.sh" --hostname=node.lab.invalid --site="$here/site.example.conf" --dryrun > "$tmp/report" || rc=$?
[ "$rc" -eq 3 ]; grep -q 'PLANNED.*DNS_Client_Set_Name_Server' "$tmp/report"; grep -q 'CENTRAL.*Central_Register_DNS' "$tmp/report"
rc=0
"$here/install-client.sh" --hostname='bad;host' --dryrun > "$tmp/bad" 2>&1 || rc=$?
[ "$rc" -eq 1 ]; grep -q 'NOT RUN' "$tmp/bad"
printf 'dns1=999.0.0.1\nsearch=lab.invalid\n' > "$tmp/bad.conf"
rc=0
"$here/install-client.sh" --hostname=node.lab.invalid --site="$tmp/bad.conf" --only=0010 > "$tmp/bad-dns" 2>&1 || rc=$?
[ "$rc" -eq 1 ]
sh "$here/tasks/0010_DNS_Client_Set_Name_Server" --hostname=node.lab.invalid --site="$here/site.example.conf" --render > "$tmp/resolver"
grep -qx 'nameserver 192.0.2.53' "$tmp/resolver"
"$here/package.sh" "$tmp/release"
(cd "$tmp/release" && sha256sum -c sasd-debian-client.tar.gz.sha256)
tar -tzf "$tmp/release/sasd-debian-client.tar.gz" | grep -q 'debian-client/install-client.sh'
echo 'Offline Debian candidate tests passed'
