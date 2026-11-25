#!/bin/sh
# Build a transport archive from the checked-out module, not runtime secrets.
set -eu
umask 077
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
[ "$#" -eq 1 ] || { echo 'usage: package.sh NEW_OUTPUT_DIRECTORY' >&2; exit 2; }
mkdir -- "$1"
out=$(CDPATH= cd -- "$1" && pwd)
tar -C "$here/.." -czf "$out/sasd-debian-client.tar.gz" debian-client/install-client.sh debian-client/tasks debian-client/lib debian-client/checklist.tsv debian-client/site.example.conf
(cd "$out" && sha256sum sasd-debian-client.tar.gz > sasd-debian-client.tar.gz.sha256)
echo 'Archive and checksum created; publish through authenticated HTTPS and pin digest independently.'
