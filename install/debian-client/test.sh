#!/bin/sh
set -eu
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT HUP INT TERM
for f in "$here"/tasks/* "$here"/lib/*.sh "$here"/*.sh; do sh -n "$f"; done
count=$(awk 'END {print NR-1}' "$here/checklist.tsv")
[ "$("$here/install-client.sh" --list | wc -l)" -eq "$count" ]
rc=0
"$here/install-client.sh" --hostname=node.lab.invalid --site="$here/site.example.conf" --dryrun > "$tmp/report" || rc=$?
[ "$rc" -eq 3 ]; grep -q 'PLANNED.*DNS_Client_Set_Name_Server' "$tmp/report"; grep -q 'CENTRAL.*Central_Register_DNS' "$tmp/report"
rc=0
"$here/install-client.sh" --hostname='bad;host' --dryrun > "$tmp/bad" 2>&1 || rc=$?
[ "$rc" -eq 2 ]; grep -q 'Invalid hostname' "$tmp/bad"
printf 'dns1=999.0.0.1\nsearch=lab.invalid\n' > "$tmp/bad.conf"
rc=0
"$here/install-client.sh" --hostname=node.lab.invalid --site="$tmp/bad.conf" > "$tmp/bad-dns" 2>&1 || rc=$?
[ "$rc" -eq 1 ]; grep -q 'NOT RUN' "$tmp/bad-dns"
sh "$here/tasks/0010_DNS_Client_Set_Name_Server" --hostname=node.lab.invalid --site="$here/site.example.conf" --render > "$tmp/resolver"
grep -qx 'nameserver 192.0.2.53' "$tmp/resolver"
# Duplicate prefix must fail before any task executes.
cp -R "$here" "$tmp/duplicate"
cp "$tmp/duplicate/tasks/0010_DNS_Client_Set_Name_Server" "$tmp/duplicate/tasks/0010_Duplicate"
rc=0
"$tmp/duplicate/install-client.sh" --list > "$tmp/dup-report" 2>&1 || rc=$?
[ "$rc" -eq 2 ]
# Untracked files are never bundled.
cp -R "$here" "$tmp/package-source"
printf '%s\n' 'fixture-only' > "$tmp/package-source/tasks/private.fixture"
# package.sh expects its source directory to be called debian-client.
mkdir "$tmp/build" "$tmp/bin"; cp "$here/../../bin/sasd-site-inventory" "$tmp/bin/"; mv "$tmp/package-source" "$tmp/build/debian-client"
"$tmp/build/debian-client/package.sh" "$tmp/release"
if tar -tzf "$tmp/release/sasd-debian-client.tar.gz" | grep -q 'private.fixture'; then exit 1; fi
if [ "$(id -u)" -ne 0 ]; then
    rc=0
    "$here/install-client.sh" --hostname=node.lab.invalid --site="$here/site.example.conf" --stage > "$tmp/staged-report" || rc=$?
    [ "$rc" -eq 3 ]
    candidate=$(sed -n 's/^Candidate directory: //p' "$tmp/staged-report")
    case "$candidate" in /tmp/sasd-debian-stage.*) ;; *) exit 1 ;; esac
    grep -qx 'nameserver 192.0.2.53' "$candidate/0010_DNS_Client_Set_Name_Server.candidate"
    grep -q 'staged=44 pending=72 failed=0' "$tmp/staged-report"
    rm -rf -- "$candidate"
fi
(cd "$tmp/release" && sha256sum -c sasd-debian-client.tar.gz.sha256)
tar -tzf "$tmp/release/sasd-debian-client.tar.gz" | grep -q 'debian-client/install-client.sh'
sh "$here/test-verify.sh"
sh "$here/test-apply.sh"
sh "$here/test-recovery.sh"
sh "$here/test-interruption.sh"
sh "$here/test-durability.sh"
sh "$here/test-metadata.sh"
sh "$here/test-persistent-journal.sh"
sh "$here/test-plan.sh"
sh "$here/test-dispatch.sh"
sh "$here/test-fixture-dispatch.sh"
sh "$here/test-native-preflight.sh"
sh "$here/test-native-capabilities.sh"
sh "$here/test-native-identity.sh"
sh "$here/test-verify-dns.sh"
sh "$here/test-prepare-native.sh"
sh "$here/test-collect-native.sh"
sh "$here/test-lab-install.sh"
sh "$here/test-native-install.sh"
sh "$here/test-plan-packages.sh"
sh "$here/test-core-services.sh"
sh "$here/test-communications.sh"
sh "$here/test-storage.sh"
sh "$here/test-shell.sh"
sh "$here/test-security.sh"
sh "$here/test-archive.sh"
echo 'Offline Debian candidate tests passed'
