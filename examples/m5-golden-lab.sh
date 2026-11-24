#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT HUP INT TERM
source="$tmp/reference"; repo="$tmp/images"; target="$tmp/target"
mkdir -p "$source/etc/sasd" "$source/var/lib/dpkg"
printf 'm5-reference\n' > "$source/etc/hostname"
printf 'ID=sasd-lab\n' > "$source/etc/os-release"
printf 'profile=reference\n' > "$source/etc/sasd/profile"
printf 'Package: sasd-fixture\n' > "$source/var/lib/dpkg/status"
bin/sasd-golden-audit --root "$source" --profile 1999 > "$tmp/audit"
bin/sasd-golden-capture --source "$source" --repository "$repo" --image-id m5-reference --version 1.0 --profile 1999 --apply
bin/sasd-golden-catalog --repository "$repo" --list
bin/sasd-golden-catalog --repository "$repo" --verify
bin/sasd-golden-restore --repository "$repo" --image-id m5-reference --dest "$target" --apply
printf 'M5 golden laboratory: PASS\n'
