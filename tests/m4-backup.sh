#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT HUP INT TERM
prefix="$tmp/server"; restored="$tmp/restored"
install/install-monitoring-server.sh --prefix "$prefix" --config site/monitoring.conf --apply >/dev/null
printf 'web.lab.invalid\tdisk\tgreen\tbackup fixture\n' > "$tmp/status.tsv"
"$prefix/bin/sasd-monitor-import" --config "$prefix/etc/sasd-monitor.conf" --input "$tmp/status.tsv" --received-at 1000 --source test >/dev/null
"$prefix/bin/sasd-monitor-cycle" --config "$prefix/etc/sasd-monitor.conf" --now 1001 >/dev/null
"$prefix/bin/sasd-monitor-control" --config "$prefix/etc/sasd-monitor.conf" --action maintenance-add --host web.lab.invalid --check disk --until 2000000000 --operator admin --reason backup >/dev/null
printf 'do-not-backup-private-key\n' > "$prefix/var/enrollment/keys/private"
bin/sasd-monitor-backup --root "$prefix" --out "$tmp/sasd.tar" >/dev/null
tar -tf "$tmp/sasd.tar" | grep -q '^var/status/state.tsv$'
if tar -tf "$tmp/sasd.tar" | grep -q 'var/enrollment/keys'; then echo 'private key included' >&2; exit 1; fi
bin/sasd-monitor-restore --archive "$tmp/sasd.tar" --dest "$restored" >/dev/null
cmp "$prefix/etc/sasd-monitor.conf" "$restored/etc/sasd-monitor.conf"
cmp "$prefix/var/status/state.tsv" "$restored/var/status/state.tsv"
cmp "$prefix/var/operations/maintenance.tsv" "$restored/var/operations/maintenance.tsv"
if bin/sasd-monitor-restore --archive "$tmp/sasd.tar" --dest "$restored" >/dev/null 2>&1; then echo 'existing destination accepted' >&2; exit 1; fi
if bin/sasd-monitor-restore --archive "$tmp/missing.tar" --dest "$tmp/missing-dest" >/dev/null 2>&1; then echo 'missing archive accepted' >&2; exit 1; fi
printf 'not a tar archive\n' > "$tmp/bad.tar"
if bin/sasd-monitor-restore --archive "$tmp/bad.tar" --dest "$tmp/bad-dest" >/dev/null 2>&1; then echo 'corrupt archive accepted' >&2; exit 1; fi
echo "M4 backup/restore: PASS"
