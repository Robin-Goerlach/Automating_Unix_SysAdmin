#!/bin/sh
set -eu
usage(){ echo "usage: release/package-1.0.sh --out DIR [--ref REF] [--test]" >&2; exit 2; }
out= ref=HEAD test=0
while [ "$#" -gt 0 ]; do
    case "$1" in
        --out) [ "$#" -ge 2 ] || usage; out=$2; shift 2 ;;
        --ref) [ "$#" -ge 2 ] || usage; ref=$2; shift 2 ;;
        --test) test=1; shift ;;
        --help) usage ;;
        *) usage ;;
    esac
done
[ -n "$out" ] || usage
case "$out" in /*) ;; *) echo "output must be absolute" >&2; exit 2 ;; esac
[ -d "$out" ] || { [ ! -e "$out" ] && mkdir -p "$out"; }
[ -d "$out" ] && [ ! -L "$out" ] || { echo "invalid output directory" >&2; exit 2; }
root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$root"
git rev-parse --verify "$ref^{commit}" >/dev/null || { echo "invalid git ref" >&2; exit 2; }
commit=$(git rev-parse "$ref^{commit}")
name=sasd-1.0.0-src
tarfile="$out/$name.tar.gz"
[ ! -e "$tarfile" ] || { echo "archive exists" >&2; exit 2; }
git archive --format=tar --prefix="$name/" "$commit" | gzip -n > "$tarfile"
git ls-tree -r --name-only "$commit" > "$out/MANIFEST-1.0.txt"
sha256sum "$tarfile" "$out/MANIFEST-1.0.txt" > "$out/SHA256SUMS"
if [ "$test" -eq 1 ]; then
    tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT HUP INT TERM
    tar -xzf "$tarfile" -C "$tmp"
    (cd "$tmp/$name" && \
        perl tests/check-eol.pl bin/* tests/*.sh tests/*.pl examples/*.sh install/*.sh lib/SASD/*.pm site/*.tsv Makefile release/*.sh && \
        sh tests/smoke.sh && sh tests/classic.sh && sh tests/bb-hosts.sh && \
        sh tests/r2-site.sh && sh tests/m1-monitoring.sh && sh tests/m2-enrollment.sh && \
        sh tests/m2-transport.sh && sh tests/m4-backup.sh && sh tests/m4-operations.sh >/dev/null)
    test -f "$tmp/$name/README.md"
    echo "clean-extraction=PASS"
fi
echo "archive=$tarfile"
echo "manifest=$out/MANIFEST-1.0.txt"
echo "checksums=$out/SHA256SUMS"
