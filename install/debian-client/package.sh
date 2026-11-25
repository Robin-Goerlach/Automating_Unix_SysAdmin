#!/bin/sh
# Build a transport archive from the reviewed catalog, not untracked runtime files.
set -eu
umask 077
LC_ALL=C; export LC_ALL
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
[ "$#" -eq 1 ] || { echo 'usage: package.sh NEW_OUTPUT_DIRECTORY' >&2; exit 2; }
[ ! -L "$here/tasks" ] && [ ! -L "$here/lib" ] || exit 2
# Fixed files plus the explicit traceability catalog; never include extra files.
catalog="$here/checklist.tsv"
[ -f "$catalog" ] && [ ! -L "$catalog" ] || exit 2
names=$(awk -F '\t' 'NR==1 {next} NF!=5 || $1 !~ /^[0-9][0-9][0-9][0-9]$/ || $3 !~ /^[A-Za-z0-9_]+$/ || seen[$1]++ {bad=1; next} {print $1 "_" $3} END{if(bad || NR<2) exit 1}' "$catalog") || exit 2
set -- "$1" debian-client/install-client.sh debian-client/verify-baseline.sh debian-client/apply-baseline.sh debian-client/lib/task.sh debian-client/lib/policy.sh debian-client/checklist.tsv debian-client/site.example.conf debian-client/package-policy.tsv debian-client/inventory-fields.tsv
for name in $names; do set -- "$@" "debian-client/tasks/$name"; done
destination=$1; shift
for file do
    [ -f "$here/../$file" ] && [ ! -L "$here/../$file" ] || { echo 'Invalid package member' >&2; exit 2; }
done
mkdir -- "$destination"
out=$(CDPATH= cd -- "$destination" && pwd)
tar -C "$here/.." -czf "$out/sasd-debian-client.tar.gz" -- "$@"
(cd "$out" && sha256sum sasd-debian-client.tar.gz > sasd-debian-client.tar.gz.sha256)
echo 'Archive and checksum created; publish through authenticated HTTPS and pin digest independently.'
