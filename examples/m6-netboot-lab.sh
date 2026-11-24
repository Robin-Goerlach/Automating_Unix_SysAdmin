#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT HUP INT TERM
printf 'PXE test boot file\n' > "$tmp/pxelinux.0"
sha=$(sha256sum "$tmp/pxelinux.0" | awk '{print $1}')
printf 'm6-image\t1.0\t%s\tfile:///lab/m6.tar\n' "$sha" > "$tmp/images.tsv"
printf 'lab-web\tLinux\tx86_64\timage\tfile:///lab/m6.tar\tm6-image\tweb\trootfs\tpostinstall.sh\tweb\n' > "$tmp/profiles.tsv"
printf 'new-web\t52:54:00:00:00:10\t192.0.2.30\t192.0.2.1\t/tftp\tpxelinux.0\tx86_64\tlab-web\n' > "$tmp/hosts.tsv"
bin/sasd-netboot-config --hosts "$tmp/hosts.tsv" --profiles "$tmp/profiles.tsv" --images "$tmp/images.tsv" --format dnsmasq --dry-run
bin/sasd-netboot-stage --source "$tmp/pxelinux.0" --tftp-root "$tmp/tftp" --profile lab-web --boot-file pxelinux.0 --sha256 "$sha" --apply
printf 'M6 netboot laboratory: PASS (configuration and staging only; no DHCP/TFTP service started)\n'
