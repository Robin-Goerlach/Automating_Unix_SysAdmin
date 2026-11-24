#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

server="$tmp/server"
install/install-monitoring-server.sh --prefix "$server" --config site/monitoring.conf --apply >/dev/null
install/install-sasd-client.sh --prefix "$tmp/client" --host enrolled.lab.invalid --role web --profile web --expires-at 2000000000 --apply >/dev/null
"$server/bin/sasd-enrollment" --dir "$server/var/enrollment" --action import-request --request "$tmp/client/var/enrollment.request" >/dev/null
"$server/bin/sasd-enrollment" --dir "$server/var/enrollment" --action approve --host enrolled.lab.invalid --operator admin --at 1000 >/dev/null
printf 'enrolled.lab.invalid\tdisk\tgreen\ttransport fixture\n' > "$tmp/status.tsv"
"$tmp/client/bin/sasd-node-status" --host enrolled.lab.invalid --key "$tmp/client/etc/identity" --sequence 1 --sent-at 1000 --input "$tmp/status.tsv" --out "$tmp/payload" >/dev/null
: > "$tmp/known_hosts"
if "$tmp/client/bin/sasd-node-send" --server monitor.lab.invalid --user sasd --port 22 --identity "$tmp/client/etc/identity" --known-hosts "$tmp/known_hosts" --payload "$tmp/payload" --signature "$tmp/payload.sig" --send >"$tmp/send.out" 2>"$tmp/send.err"; then
    echo "unexpected live SSH success without sshd" >&2; exit 1
fi
grep -q 'Host key verification failed\|Could not resolve hostname\|Connection refused\|No route to host' "$tmp/send.err" || { cat "$tmp/send.err" >&2; exit 1; }

"$server/bin/sasd-monitor-receive" --config "$server/etc/sasd-monitor.conf" --host enrolled.lab.invalid --stdio < "$tmp/payload" >"$tmp/truncated.out" 2>"$tmp/truncated.err" || true
grep -q 'invalid transport frame\|truncated transport frame' "$tmp/truncated.err"
printf 'SASD-SSH-1\tenrolled.lab.invalid\t1\t1\nX' | "$server/bin/sasd-monitor-receive" --config "$server/etc/sasd-monitor.conf" --host enrolled.lab.invalid --stdio >"$tmp/frame.out" 2>"$tmp/frame.err" || true
grep -q 'truncated transport frame' "$tmp/frame.err"
if "$tmp/client/bin/sasd-node-send" --server monitor.lab.invalid --user sasd --port 22 --identity "$tmp/client/etc/identity" --known-hosts "$tmp/known_hosts" --payload "$tmp/payload" --signature "$tmp/payload.sig" --dry-run >/dev/null; then :; else exit 1; fi
echo "M2.1 transport validation: PASS (offline framing/negative checks; live sshd unavailable)"
