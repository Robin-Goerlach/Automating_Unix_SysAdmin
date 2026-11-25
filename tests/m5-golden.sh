#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT HUP INT TERM
source="$tmp/reference"; repo="$tmp/images"; restored="$tmp/restored"
mkdir -p "$source/etc/ssh" "$source/etc/sasd" "$source/root/.ssh" "$source/tmp" "$source/var/lib/dpkg"
printf 'golden-lab\n' > "$source/etc/hostname"
printf 'ID=sasd-lab\nVERSION_ID=1\n' > "$source/etc/os-release"
printf 'fixture monitoring configuration\n' > "$source/etc/sasd/config"
printf 'Package: sasd-fixture\n' > "$source/var/lib/dpkg/status"
printf 'host private key\n' > "$source/etc/ssh/ssh_host_key"
printf 'client private key\n' > "$source/root/.ssh/id_key"
printf 'temporary data\n' > "$source/tmp/should-not-be-captured"

bin/sasd-golden-audit --root "$source" --profile lab > "$tmp/audit"
awk -F '\t' '$1 == "snapshot_capability" && $2 == "not-checked" { found=1 } END { exit !found }' "$tmp/audit"
test "$(cat "$source/etc/hostname")" = golden-lab

bin/sasd-golden-capture --source "$source" --repository "$repo" --image-id lab-1 --version 1 --profile 1999 --dry-run > "$tmp/dry-run"
grep -q 'capture=dry-run' "$tmp/dry-run"
bin/sasd-golden-capture --source "$source" --repository "$repo" --image-id lab-1 --version 1 --profile 1999 --apply
if bin/sasd-golden-capture --source "$source" --repository "$repo" --image-id lab-1 --version 1 --profile 1999 --apply >/dev/null 2>&1; then
    echo "capture overwrote an existing image" >&2; exit 1
fi
bin/sasd-golden-catalog --repository "$repo" --verify > "$tmp/catalog"
grep -q 'verified=lab-1' "$tmp/catalog"
test "$(ls -l "$repo/archives/lab-1.tar" | awk '{print $1}')" = -rw-------
test "$(ls -l "$repo/manifests/lab-1.tsv" | awk '{print $1}')" = -rw-------
test "$(ls -l "$repo/checksums/lab-1.sha256" | awk '{print $1}')" = -rw-------

bin/sasd-golden-restore --repository "$repo" --image-id lab-1 --dest "$restored" --dry-run > "$tmp/restore-dry"
grep -q 'restore=dry-run' "$tmp/restore-dry"
bin/sasd-golden-restore --repository "$repo" --image-id lab-1 --dest "$restored" --apply
cmp "$source/etc/hostname" "$restored/etc/hostname"
test ! -e "$restored/tmp/should-not-be-captured"
test ! -e "$restored/etc/ssh/ssh_host_key"
test ! -e "$restored/root/.ssh/id_key"
checksum="$repo/checksums/lab-1.sha256"
cp "$checksum" "$tmp/checksum.good"
printf '0000000000000000000000000000000000000000000000000000000000000000  archives/lab-1.tar\n' > "$checksum"
if bin/sasd-golden-restore --repository "$repo" --image-id lab-1 --dest "$tmp/checksum-fail" --dry-run >/dev/null 2>&1; then
    echo "bad checksum record accepted" >&2; exit 1
fi
mv "$tmp/checksum.good" "$checksum"
mkdir "$tmp/existing"
if bin/sasd-golden-restore --repository "$repo" --image-id lab-1 --dest "$tmp/existing" --apply >/dev/null 2>&1; then
    echo "existing destination overwritten" >&2; exit 1
fi

mkdir -p "$tmp/symlink-source/etc"
printf 'safe\n' > "$tmp/symlink-source/etc/file"
ln -s /tmp "$tmp/symlink-source/etc/unsafe-link"
if bin/sasd-golden-capture --source "$tmp/symlink-source" --repository "$repo" --image-id symlink-1 --version 1 --profile lab --apply >/dev/null 2>&1; then
    echo "symlink archive accepted" >&2; exit 1
fi

ln "$source/etc/hostname" "$source/etc/hardlink"
if bin/sasd-golden-capture --source "$source" --repository "$repo" --image-id hardlink-1 --version 1 --profile lab --apply >/dev/null 2>&1; then
    echo "hardlink archive accepted" >&2; exit 1
fi

cp "$repo/manifests/lab-1.tsv" "$tmp/manifest.good"
sed '/^sha256\t/d' "$tmp/manifest.good" > "$repo/manifests/lab-1.tsv"
if bin/sasd-golden-catalog --repository "$repo" --verify >/dev/null 2>&1; then
    echo "malformed manifest accepted" >&2; exit 1
fi
mv "$tmp/manifest.good" "$repo/manifests/lab-1.tsv"

echo "M5 golden client/archive/restore: PASS"
