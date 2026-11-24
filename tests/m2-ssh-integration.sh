#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
require=0
[ "${1:-}" = --require ] && require=1
sshd=${SSHD_BIN:-$(command -v sshd 2>/dev/null || true)}
if [ -z "$sshd" ]; then
    echo "M2.1 SSH integration: SKIPPED (sshd unavailable)"
    [ "$require" -eq 1 ] && exit 3
    exit 0
fi
tmp=$(mktemp -d); pid=; cleanup(){ [ -z "$pid" ] || kill "$pid" 2>/dev/null || true; rm -rf "$tmp"; }; trap cleanup EXIT HUP INT TERM
server="$tmp/server"; client="$tmp/client"; port=$((22000 + ($$ % 1000)))
install/install-monitoring-server.sh --prefix "$server" --config site/monitoring.conf --apply >/dev/null
install/install-sasd-client.sh --prefix "$client" --host enrolled.lab.invalid --role web --profile web --expires-at 2000000000 --apply >/dev/null
"$server/bin/sasd-enrollment" --dir "$server/var/enrollment" --action import-request --request "$client/var/enrollment.request" >/dev/null
"$server/bin/sasd-enrollment" --dir "$server/var/enrollment" --action approve --host enrolled.lab.invalid --operator admin --at 1000 >/dev/null
ssh-keygen -q -t ed25519 -N '' -f "$tmp/server-host" >/dev/null
pub=$(sed -n '1p' "$client/etc/identity.pub")
printf 'command="%s/bin/sasd-monitor-receive --config %s/etc/sasd-monitor.conf --host enrolled.lab.invalid --stdio",no-pty,no-agent-forwarding,no-port-forwarding,no-X11-forwarding %s\n' "$server" "$server" "$pub" > "$tmp/authorized_keys"
{
    printf 'Port %s\n' "$port"
    printf 'ListenAddress 127.0.0.1\nHostKey %s\nPidFile %s/sshd.pid\nAuthorizedKeysFile %s/authorized_keys\n' "$tmp/server-host" "$tmp" "$tmp"
    printf '%s\n' 'PasswordAuthentication no' 'KbdInteractiveAuthentication no' 'UsePAM no' 'StrictModes no' 'PermitRootLogin no' 'LogLevel VERBOSE'
} > "$tmp/sshd_config"
"$sshd" -D -e -f "$tmp/sshd_config" > "$tmp/sshd.log" 2>&1 & pid=$!
for i in 1 2 3 4 5 6 7 8 9 10; do ssh-keyscan -T 1 -p "$port" 127.0.0.1 > "$tmp/known_hosts" 2>/dev/null && break; sleep 1; done
kill -0 "$pid" 2>/dev/null || { cat "$tmp/sshd.log" >&2; exit 4; }
[ -s "$tmp/known_hosts" ] || { cat "$tmp/sshd.log" >&2; exit 4; }
printf 'enrolled.lab.invalid\tdisk\tgreen\tactual ssh fixture\n' > "$tmp/status.tsv"
sent=$(date +%s)
"$client/bin/sasd-node-status" --host enrolled.lab.invalid --key "$client/etc/identity" --sequence 1 --sent-at "$sent" --input "$tmp/status.tsv" --out "$tmp/payload" >/dev/null
"$client/bin/sasd-node-send" --server 127.0.0.1 --user "$(id -un)" --port "$port" --identity "$client/etc/identity" --known-hosts "$tmp/known_hosts" --payload "$tmp/payload" --signature "$tmp/payload.sig" --send > "$tmp/send.log"
grep -q 'transport-send=OK' "$tmp/send.log"
grep -q 'enrolled.lab.invalid.disk' "$server/var/status/latest"/*
: > "$tmp/empty_known_hosts"
if "$client/bin/sasd-node-send" --server 127.0.0.1 --user "$(id -un)" --port "$port" --identity "$client/etc/identity" --known-hosts "$tmp/empty_known_hosts" --payload "$tmp/payload" --signature "$tmp/payload.sig" --send >/dev/null 2>&1; then
    echo "unknown server key accepted" >&2
    exit 1
fi
echo "M2.1 SSH integration: PASS sshd=$sshd"
