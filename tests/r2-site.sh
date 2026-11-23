#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

./bin/sasd-site-inventory --input site/hosts.tsv --roles site/roles.tsv --check > "$tmp/check"
grep -q 'hosts=4 roles=4 status=OK' "$tmp/check"
./bin/sasd-site-inventory --input site/hosts.tsv --roles site/roles.tsv --role web > "$tmp/web"
grep -q '^web.lab.invalid' "$tmp/web"
./bin/sasd-site-classes --input site/hosts.tsv --roles site/roles.tsv --host web.lab.invalid > "$tmp/classes"
grep -q 'baseline,role_web,group_lab' "$tmp/classes"
./bin/sasd-site-audit --input site/hosts.tsv --roles site/roles.tsv --host web.lab.invalid --root fixtures/site/actual --golden fixtures/site/golden --status > "$tmp/audit"
grep -q '^web.lab.invalid.*config-audit.*green' "$tmp/audit"
./bin/sasd-site-audit --input site/hosts.tsv --roles site/roles.tsv --host web.lab.invalid --root fixtures/site/actual --golden fixtures/site/golden --status | tail -n 1 | ./bin/sasd-status-store --spool "$tmp" > "$tmp/store"
grep -q 'stored=1' "$tmp/store"

printf 'changed\n' > "$tmp/actual-marker"
cp -R fixtures/site/actual "$tmp/changed-root"
cp "$tmp/actual-marker" "$tmp/changed-root/etc/site-marker"
if ./bin/sasd-site-audit --input site/hosts.tsv --roles site/roles.tsv --host web.lab.invalid --root "$tmp/changed-root" --golden fixtures/site/golden --status > "$tmp/drift"; then
    echo "expected configuration drift" >&2
    exit 1
fi
grep -q '^web.lab.invalid.*config-audit.*yellow' "$tmp/drift"
./bin/sasd-site-audit --input site/hosts.tsv --roles site/roles.tsv --host web.lab.invalid --root "$tmp/changed-root" --golden fixtures/site/golden --status | tail -n 1 | ./bin/sasd-status-store --spool "$tmp" > "$tmp/drift-store"
./bin/sasd-status-board --spool "$tmp" --out "$tmp/drift-board.html"
grep -q 'class="yellow"' "$tmp/drift-board.html"

printf 'etc/site-marker\tcommon/not-present\n' > "$tmp/missing-manifest.tsv"
if ./bin/sasd-config-drift --root fixtures/site/actual --golden fixtures/site/golden --manifest "$tmp/missing-manifest.tsv" > "$tmp/missing"; then
    echo "missing reference accepted" >&2
    exit 1
fi
grep -q '^UNKNOWN' "$tmp/missing"

sed 's/$/\r/' site/hosts.tsv > "$tmp/crlf-hosts.tsv"
./bin/sasd-site-inventory --input "$tmp/crlf-hosts.tsv" --roles site/roles.tsv --check > "$tmp/crlf-check"
grep -q 'status=OK' "$tmp/crlf-check"

printf '# duplicate\nweb.lab.invalid\t192.0.2.20\tunix\tweb\tlab\tweb\n' > "$tmp/duplicate.tsv"
cat site/hosts.tsv >> "$tmp/duplicate.tsv"
if ./bin/sasd-site-inventory --input "$tmp/duplicate.tsv" --roles site/roles.tsv --check > "$tmp/error" 2>&1; then
    echo "duplicate hostname accepted" >&2
    exit 1
fi
grep -q 'duplicate hostname' "$tmp/error"

printf '# bad address\nweb.lab.invalid\t192.0.2.999\tunix\tweb\tlab\tweb\n' > "$tmp/bad.tsv"
if ./bin/sasd-site-inventory --input "$tmp/bad.tsv" --roles site/roles.tsv --check > "$tmp/bad-error" 2>&1; then
    echo "invalid address accepted" >&2
    exit 1
fi
grep -q 'invalid host record' "$tmp/bad-error"

printf '# unknown role\nnew.lab.invalid\t192.0.2.20\tunix\tunknown\tlab\tbaseline\n' > "$tmp/unknown.tsv"
if ./bin/sasd-site-inventory --input "$tmp/unknown.tsv" --roles site/roles.tsv --check > "$tmp/unknown-error" 2>&1; then
    echo "unknown role accepted" >&2
    exit 1
fi
grep -q "unknown role" "$tmp/unknown-error"

printf '# unsafe path\netc/../secret\t192.0.2.20\tunix\tweb\tlab\tweb\n' > "$tmp/unsafe.tsv"
if ./bin/sasd-site-inventory --input "$tmp/unsafe.tsv" --roles site/roles.tsv --check > "$tmp/unsafe-error" 2>&1; then
    echo "unsafe hostname accepted" >&2
    exit 1
fi
grep -q 'invalid host record' "$tmp/unsafe-error"
echo "R2 site inventory and audit: PASS"
