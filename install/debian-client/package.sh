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
set -- "$1" debian-client/install-client.sh debian-client/dispatch-planned.sh debian-client/dispatch-fixture.sh debian-client/plan-client.pl debian-client/native-preflight.pl debian-client/native-capabilities.py debian-client/native-identity.py debian-client/prepare-native.sh debian-client/collect-native.sh debian-client/verify-dns.pl debian-client/lab-install.py debian-client/native-install.py debian-client/plan-packages.py debian-client/dependencies.tsv debian-client/verify-baseline.sh debian-client/apply-baseline.sh debian-client/recover-baseline.sh debian-client/lib/transaction.sh debian-client/lib/task.sh debian-client/lib/policy.sh debian-client/lib/baseline-render.sh debian-client/checklist.tsv debian-client/site.example.conf debian-client/package-policy.tsv debian-client/inventory-fields.tsv
for name in $names; do set -- "$@" "debian-client/tasks/$name"; done
destination=$1; shift
for file do
    [ -f "$here/../$file" ] && [ ! -L "$here/../$file" ] || { echo 'Invalid package member' >&2; exit 2; }
done
validator="$here/../../bin/sasd-site-inventory"
[ -f "$validator" ] && [ ! -L "$validator" ] || { echo 'Canonical R2 validator missing' >&2; exit 2; }
bundle=$(mktemp -d)
trap 'rm -rf -- "$bundle"' EXIT
trap 'exit 1' HUP INT TERM
(cd "$here/.." && cp -p --parents -- "$@" "$bundle")
cp -p -- "$validator" "$bundle/debian-client/lib/sasd-site-inventory"
mkdir -- "$destination"
out=$(CDPATH= cd -- "$destination" && pwd)
tar -C "$bundle" -czf "$out/sasd-debian-client.tar.gz" -- debian-client
(cd "$out" && sha256sum sasd-debian-client.tar.gz > sasd-debian-client.tar.gz.sha256)
echo 'Archive and checksum created; publish through authenticated HTTPS and pin digest independently.'
