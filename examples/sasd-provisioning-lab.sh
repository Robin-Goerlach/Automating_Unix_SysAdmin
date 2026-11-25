#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT HUP INT TERM
reference="$tmp/reference"; images="$tmp/images"; tftp="$tmp/tftp"; server="$tmp/server"; client="$tmp/client"
mkdir -p "$reference/etc/sasd" "$reference/var/lib/dpkg"
printf 'provisioning-reference\n' > "$reference/etc/hostname"
printf 'ID=sasd-lab\n' > "$reference/etc/os-release"
printf 'reference monitoring profile\n' > "$reference/etc/sasd/profile"
printf 'Package: sasd-fixture\n' > "$reference/var/lib/dpkg/status"
bin/sasd-golden-audit --root "$reference" --profile 1999 > "$tmp/audit"
bin/sasd-golden-capture --source "$reference" --repository "$images" --image-id golden-1 --version 1.0 --profile 1999 --apply >/dev/null
bin/sasd-golden-catalog --repository "$images" --verify >/dev/null
image_sha=$(awk -F '\t' '$1 == "sha256" {print $2}' "$images/manifests/golden-1.tsv")
printf 'golden-1\t1.0\t%s\t%s\n' "$image_sha" "$images/archives/golden-1.tar" > "$tmp/images.tsv"
printf 'web-lab\tLinux\t%s\timage\t%s\tgolden-1\tweb\trootfs\tpostinstall.sh\tweb\n' "$(uname -m)" "$images/archives/golden-1.tar" > "$tmp/profiles.tsv"
printf 'new-web\t52:54:00:00:00:30\t192.0.2.40\t192.0.2.1\t/tftp\tpxelinux.0\t%s\tweb-lab\n' "$(uname -m)" > "$tmp/hosts.tsv"
printf 'test boot file\n' > "$tmp/pxelinux.0"
boot_sha=$(sha256sum "$tmp/pxelinux.0" | awk '{print $1}')
bin/sasd-netboot-config --hosts "$tmp/hosts.tsv" --profiles "$tmp/profiles.tsv" --images "$tmp/images.tsv" --format dnsmasq --dry-run > "$tmp/dhcp.conf"
bin/sasd-netboot-stage --source "$tmp/pxelinux.0" --tftp-root "$tftp" --profile web-lab --boot-file pxelinux.0 --sha256 "$boot_sha" --apply >/dev/null
install/install-monitoring-server.sh --prefix "$server" --config site/monitoring.conf --apply >/dev/null
bin/sasd-postinstall --root "$client" --profile-file "$tmp/profiles.tsv" --images "$tmp/images.tsv" --image-version 1.0 --profile web-lab --host new-web.lab.invalid --expires-at 2000000000 --apply >/dev/null
"$server/bin/sasd-enrollment" --dir "$server/var/enrollment" --action import-request --request "$client/var/enrollment.request" >/dev/null
"$server/bin/sasd-enrollment" --dir "$server/var/enrollment" --action approve --host new-web.lab.invalid --operator admin --at 1000 >/dev/null
printf 'new-web.lab.invalid\tdisk\tgreen\tprovisioned host healthy\n' > "$tmp/status.tsv"
"$client/bin/sasd-node-status" --host new-web.lab.invalid --key "$client/etc/identity" --sequence 1 --sent-at 1000 --input "$tmp/status.tsv" --out "$tmp/payload" >/dev/null
"$server/bin/sasd-monitor-auth-import" --config "$server/etc/sasd-monitor.conf" --input "$tmp/payload" --signature "$tmp/payload.sig" --now 1050 >/dev/null
"$server/bin/sasd-monitor-cycle" --config "$server/etc/sasd-monitor.conf" --now 1050 >/dev/null
"$server/bin/sasd-monitor-report" --config "$server/etc/sasd-monitor.conf" --out "$tmp/report.html" >/dev/null
grep -q 'new-web.lab.invalid' "$tmp/report.html"
printf 'SASD provisioning laboratory: PASS\n'
printf 'coverage=offline audit,capture,catalog,netboot-config,tftp-stage,postinstall,enrollment,authenticated-monitoring\n'
printf 'not-tested=real DHCP/TFTP/network boot,OS installation,SSH network transport,hardware boot,historical Unix\n'
