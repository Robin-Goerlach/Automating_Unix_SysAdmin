#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT HUP INT TERM
printf 'bootloader fixture\n' > "$tmp/boot.bin"
sha=$(sha256sum "$tmp/boot.bin" | awk '{print $1}')
printf 'img1\t1.0\t%s\t/tmp/image.tar\n' "$sha" > "$tmp/images.tsv"
printf 'p1\tLinux\tx86_64\timage\tfile:///lab/image.tar\timg1\tweb\trootfs\tpostinstall.sh\tweb\np2\tSunOS\tsparc\tjumpstart\tnfs://192.0.2.5/install\timg1\tweb\tufs\tfinish.sh\tweb\n' > "$tmp/profiles.tsv"
printf 'host-a\t52:54:00:00:00:01\t192.0.2.20\t192.0.2.1\t/tftp\tpxelinux.0\tx86_64\tp1\nhost-b\t52:54:00:00:00:02\t192.0.2.21\t192.0.2.1\t/tftp\tboot\tsparc\tp2\n' > "$tmp/hosts.tsv"

for format in isc-dhcp dnsmasq bootp; do
    bin/sasd-netboot-config --hosts "$tmp/hosts.tsv" --profiles "$tmp/profiles.tsv" --images "$tmp/images.tsv" --format "$format" --dry-run > "$tmp/$format.conf"
    grep -q 'host-a\|dhcp-host' "$tmp/$format.conf"
done
if grep -Eiq 'password|secret|private key|BEGIN .* KEY' "$tmp"/*.conf; then echo "secret leaked into netboot config" >&2; exit 1; fi
if grep -Eiq 'password[[:space:]]*=|BEGIN .* KEY|community[[:space:]]*=' site/install/adapters/*; then echo "secret-like adapter content found" >&2; exit 1; fi
bin/sasd-netboot-config --hosts "$tmp/hosts.tsv" --profiles "$tmp/profiles.tsv" --images "$tmp/images.tsv" --format isc-dhcp --out "$tmp/dhcp.conf" --apply
if bin/sasd-netboot-config --hosts "$tmp/hosts.tsv" --profiles "$tmp/profiles.tsv" --images "$tmp/images.tsv" --format isc-dhcp --out "$tmp/dhcp.conf" --apply >/dev/null 2>&1; then echo "config overwrite accepted" >&2; exit 1; fi

cp "$tmp/hosts.tsv" "$tmp/duplicate.tsv"
printf 'host-c\t52:54:00:00:00:01\t192.0.2.22\t192.0.2.1\t/tftp\tboot\tx86_64\tp1\n' >> "$tmp/duplicate.tsv"
if bin/sasd-netboot-config --hosts "$tmp/duplicate.tsv" --profiles "$tmp/profiles.tsv" --images "$tmp/images.tsv" --format dnsmasq --dry-run >/dev/null 2>&1; then echo "duplicate MAC accepted" >&2; exit 1; fi
printf 'bad\tLinux\tx86_64\timage\tpassword=bad\timg1\tweb\trootfs\tpost.sh\tweb\n' > "$tmp/bad-profiles.tsv"
if bin/sasd-netboot-config --hosts "$tmp/hosts.tsv" --profiles "$tmp/bad-profiles.tsv" --images "$tmp/images.tsv" --format dnsmasq --dry-run >/dev/null 2>&1; then echo "secret profile accepted" >&2; exit 1; fi

bin/sasd-netboot-stage --source "$tmp/boot.bin" --tftp-root "$tmp/tftp" --profile p1 --boot-file pxelinux.0 --sha256 "$sha" --dry-run > "$tmp/stage-dry"
grep -q 'stage=dry-run' "$tmp/stage-dry"
test ! -e "$tmp/tftp"
bin/sasd-netboot-stage --source "$tmp/boot.bin" --tftp-root "$tmp/tftp" --profile p1 --boot-file pxelinux.0 --sha256 "$sha" --apply
bin/sasd-netboot-stage --source "$tmp/boot.bin" --tftp-root "$tmp/tftp" --profile p2 --boot-file boot --apply
test "$(wc -l < "$tmp/tftp/tftp-manifest.tsv")" -eq 3
if bin/sasd-netboot-stage --source "$tmp/boot.bin" --tftp-root "$tmp/tftp" --profile p1 --boot-file pxelinux.0 --apply >/dev/null 2>&1; then echo "duplicate TFTP stage accepted" >&2; exit 1; fi
if bin/sasd-netboot-stage --source "$tmp/boot.bin" --tftp-root "$tmp/tftp2" --profile p1 --boot-file ../escape --apply >/dev/null 2>&1; then echo "unsafe boot path accepted" >&2; exit 1; fi
if bin/sasd-netboot-stage --source "$tmp/boot.bin" --tftp-root "$tmp/tftp3" --profile p1 --boot-file boot --sha256 0000000000000000000000000000000000000000000000000000000000000000 --apply >/dev/null 2>&1; then echo "wrong boot checksum accepted" >&2; exit 1; fi
ln -s "$tmp/tftp" "$tmp/tftp-link"
if bin/sasd-netboot-stage --source "$tmp/boot.bin" --tftp-root "$tmp/tftp-link" --profile p3 --boot-file boot --apply >/dev/null 2>&1; then echo "symlink TFTP root accepted" >&2; exit 1; fi

echo "M6 netboot configuration/staging: PASS (offline; no network listener or boot performed)"
