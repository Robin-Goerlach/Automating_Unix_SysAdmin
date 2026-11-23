#!/bin/sh
# Reproduce the synthetic 1999-style status cycle in a user-chosen directory.
set -eu
if [ "$#" -ne 1 ]; then
    echo "usage: sh examples/demo.sh EXISTING_PRIVATE_DIRECTORY" >&2
    exit 2
fi
root=$1
[ -d "$root" ] && [ ! -L "$root" ] || {
    echo "output must be an existing private directory" >&2
    exit 2
}
repo=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
mkdir "$root/status"
"$repo/bin/sasd-disk-watch" --host lab-host --input "$repo/fixtures/df/healthy.txt"
"$repo/bin/sasd-status-store" --spool "$root/status" --input "$repo/fixtures/status/disk.tsv"
"$repo/bin/sasd-status-board" --spool "$root/status" --out "$root/index.html"
"$repo/bin/sasd-config-drift" --root "$repo/fixtures/config/actual" --golden "$repo/fixtures/config/golden" --manifest "$repo/fixtures/config/manifest.tsv"
"$repo/bin/sasd-mrtg-counter" --input "$repo/fixtures/mrtg/ifcounters.tsv"
printf 'Open %s/index.html locally\n' "$root"
