#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT HUP INT TERM
profile_file="$tmp/profiles.tsv"
printf 'img1\t1.0\t%s\tfile:///lab/web.tar\n' "$(printf 'image-fixture\n' | sha256sum | awk '{print $1}')" > "$tmp/images.tsv"
printf 'web-lab\tLinux\t%s\timage\tfile:///lab/web.tar\timg1\tweb\trootfs\tpostinstall.sh\tweb\n' "$(uname -m)" > "$profile_file"
server="$tmp/server"; client="$tmp/client"
install/install-monitoring-server.sh --prefix "$server" --config site/monitoring.conf --apply >/dev/null
bin/sasd-postinstall --root "$client" --profile-file "$profile_file" --images "$tmp/images.tsv" --image-version 1.0 --profile web-lab --host new-web.lab.invalid --expires-at 2000000000 --apply >/dev/null
"$server/bin/sasd-enrollment" --dir "$server/var/enrollment" --action import-request --request "$client/var/enrollment.request" >/dev/null
"$server/bin/sasd-enrollment" --dir "$server/var/enrollment" --action approve --host new-web.lab.invalid --operator admin --at 1000 >/dev/null
printf 'new-web.lab.invalid\tdisk\tgreen\tpostinstall status\n' > "$tmp/status.tsv"
"$client/bin/sasd-node-status" --host new-web.lab.invalid --key "$client/etc/identity" --sequence 1 --sent-at 1000 --input "$tmp/status.tsv" --out "$tmp/payload" >/dev/null
"$server/bin/sasd-monitor-auth-import" --config "$server/etc/sasd-monitor.conf" --input "$tmp/payload" --signature "$tmp/payload.sig" --now 1050 >/dev/null
"$server/bin/sasd-monitor-cycle" --config "$server/etc/sasd-monitor.conf" --now 1050 >/dev/null
grep -q 'new-web.lab.invalid' "$server/var/status/latest"/*
printf 'M7 installation-to-monitoring laboratory: PASS (offline enrollment transfer; no automatic approval)\n'
