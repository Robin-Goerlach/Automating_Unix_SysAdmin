#!/bin/sh
set -eu
usage(){ echo "usage: release/package.sh --version VERSION --out DIR [--ref REF] [--test]" >&2; exit 2; }
version= ref=HEAD out= test_mode=0
while [ "$#" -gt 0 ]; do
    case "$1" in
        --version) [ "$#" -ge 2 ] || usage; version=$2; shift 2 ;;
        --ref) [ "$#" -ge 2 ] || usage; ref=$2; shift 2 ;;
        --out) [ "$#" -ge 2 ] || usage; out=$2; shift 2 ;;
        --test) test_mode=1; shift ;;
        --help) usage ;;
        *) usage ;;
    esac
done
[ -n "$version" ] && [ -n "$out" ] || usage
case "$version" in ''|*[!A-Za-z0-9._-]*) echo "invalid version" >&2; exit 2 ;; esac
case "$out" in /*) ;; *) echo "output must be absolute" >&2; exit 2 ;; esac
[ -e "$out" ] || mkdir -p "$out"
[ -d "$out" ] && [ ! -L "$out" ] || { echo "invalid output directory" >&2; exit 2; }
root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$root"
commit=$(git rev-parse --verify "$ref^{commit}") || { echo "invalid git ref" >&2; exit 2; }
name="sasd-$version-src"
archive="$out/$name.tar.gz"; manifest="$out/MANIFEST-$version.txt"; sums="$out/SHA256SUMS"
for file in "$archive" "$manifest" "$sums"; do [ ! -e "$file" ] || { echo "artifact exists: $file" >&2; exit 2; }; done
git archive --format=tar --prefix="$name/" "$commit" | gzip -n > "$archive"
git ls-tree -r --name-only "$commit" > "$manifest"
sha256sum "$archive" "$manifest" > "$sums"
if [ "$test_mode" -eq 1 ]; then
    tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT HUP INT TERM
    tar -xzf "$archive" -C "$tmp"
    test -f "$tmp/$name/README.md"
    test -x "$tmp/$name/bin/sasd-golden-capture"
    test -x "$tmp/$name/bin/sasd-netboot-stage"
    if [ -e "$tmp/$name/release/package.sh" ]; then test -x "$tmp/$name/release/package.sh"; fi
    (cd "$tmp/$name" && perl tests/check-eol.pl bin/* tests/*.sh tests/*.pl examples/*.sh install/*.sh lib/SASD/*.pm site/*.tsv Makefile release/*.sh && sh tests/m5-golden.sh && sh tests/m6-netboot.sh && sh tests/m7-postinstall.sh)
    echo "clean-extraction=PASS"
fi
echo "source-commit=$commit"
echo "archive=$archive"
echo "manifest=$manifest"
echo "checksums=$sums"
