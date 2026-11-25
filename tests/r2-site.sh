#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

./bin/sasd-site-inventory --input site/hosts.tsv --roles site/roles.tsv --check > "$tmp/check"
grep -q 'hosts=4 roles=4 status=OK' "$tmp/check"
./bin/sasd-site-services --hosts site/hosts.tsv --roles site/roles.tsv --checks site/checks.tsv --services site/services.tsv --check > "$tmp/services-check"
grep -q 'services=5 hosts=4 status=OK' "$tmp/services-check"
./bin/sasd-site-services --hosts site/hosts.tsv --roles site/roles.tsv --checks site/checks.tsv --services site/services.tsv --host web.lab.invalid > "$tmp/web-services"
grep -q '^web.lab.invalid.*http' "$tmp/web-services"
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
printf 'bad\tweb\tmissing\t1999\tunsafe\n' > "$tmp/bad-services.tsv"
if ./bin/sasd-site-services --hosts site/hosts.tsv --roles site/roles.tsv --checks site/checks.tsv --services "$tmp/bad-services.tsv" --check > "$tmp/bad-services-error" 2>&1; then
    echo "unknown service check accepted" >&2
    exit 1
fi
grep -q 'unknown service check' "$tmp/bad-services-error"

cp site/hosts.tsv "$tmp/admin-hosts.tsv"
./bin/sasd-host-admin --input "$tmp/admin-hosts.tsv" --roles site/roles.tsv --operation validate > "$tmp/admin-validate"
grep -q 'hosts=4 states=0 status=OK' "$tmp/admin-validate"

cp site/hosts.tsv "$tmp/lifecycle-hosts.tsv"
./bin/sasd-host-admin --input "$tmp/lifecycle-hosts.tsv" --roles site/roles.tsv --operation disable --host web.lab.invalid --apply > "$tmp/lifecycle-disable"
./bin/sasd-host-admin --input "$tmp/lifecycle-hosts.tsv" --roles site/roles.tsv --operation update --host web.lab.invalid --record 'web.lab.invalid	192.0.2.21	unix	web	lab	web' --apply > "$tmp/lifecycle-update"
./bin/sasd-host-admin --input "$tmp/lifecycle-hosts.tsv" --roles site/roles.tsv --operation show --host web.lab.invalid > "$tmp/lifecycle-show"
grep -q '192.0.2.21.*disabled' "$tmp/lifecycle-show"
if ./bin/sasd-host-admin --input "$tmp/lifecycle-hosts.tsv" --roles site/roles.tsv --operation disable --host web.lab.invalid --apply > "$tmp/lifecycle-repeat" 2>&1; then
    echo "repeated disable accepted" >&2
    exit 1
fi
grep -q 'invalid state transition' "$tmp/lifecycle-repeat"
./bin/sasd-host-admin --input "$tmp/lifecycle-hosts.tsv" --roles site/roles.tsv --operation enable --host web.lab.invalid --apply > "$tmp/lifecycle-enable"
./bin/sasd-host-admin --input "$tmp/lifecycle-hosts.tsv" --roles site/roles.tsv --operation remove --host web.lab.invalid --apply > "$tmp/lifecycle-remove"
if ./bin/sasd-host-admin --input "$tmp/lifecycle-hosts.tsv" --roles site/roles.tsv --operation enable --host web.lab.invalid --apply > "$tmp/lifecycle-removed" 2>&1; then
    echo "removed host enabled without re-add" >&2
    exit 1
fi
grep -q 'host does not exist' "$tmp/lifecycle-removed"
./bin/sasd-host-admin --input "$tmp/lifecycle-hosts.tsv" --roles site/roles.tsv --operation add --host web.lab.invalid --record 'web.lab.invalid	192.0.2.22	unix	web	lab	web' --apply > "$tmp/lifecycle-add"
./bin/sasd-host-admin --input "$tmp/lifecycle-hosts.tsv" --roles site/roles.tsv --operation validate > "$tmp/lifecycle-validate"
grep -q 'hosts=4 states=1 status=OK history=5' "$tmp/lifecycle-validate"
test "$(wc -l < "$tmp/lifecycle-hosts.tsv.history.tsv")" -eq 5
grep -q '^[0-9][0-9]*	web.lab.invalid	remove	enabled	removed	operator$' "$tmp/lifecycle-hosts.tsv.history.tsv"

ln -s "$tmp/lifecycle-hosts.tsv.history.tsv" "$tmp/history-link.tsv"
if ./bin/sasd-host-admin --input "$tmp/lifecycle-hosts.tsv" --roles site/roles.tsv --history "$tmp/history-link.tsv" --operation validate > "$tmp/history-link-error" 2>&1; then
    echo "symlinked history accepted" >&2
    exit 1
fi
grep -q 'history file is a symlink' "$tmp/history-link-error"

if ./bin/sasd-host-admin --input "$tmp/admin-hosts.tsv" --roles site/roles.tsv --operation disable --host web.lab.invalid > "$tmp/admin-no-apply" 2>&1; then
    echo "host disable without apply accepted" >&2
    exit 1
fi
grep -q 'requires --apply' "$tmp/admin-no-apply"
test ! -e "$tmp/admin-hosts.tsv.lock"
./bin/sasd-host-admin --input "$tmp/admin-hosts.tsv" --roles site/roles.tsv --operation disable --host web.lab.invalid --apply > "$tmp/admin-disable"
grep -q 'status=APPLIED' "$tmp/admin-disable"
./bin/sasd-site-config --hosts "$tmp/admin-hosts.tsv" --roles site/roles.tsv --checks site/checks.tsv --services site/services.tsv --check > "$tmp/site-config-check"
grep -q 'hosts=3 selections=8 status=OK' "$tmp/site-config-check"
./bin/sasd-site-config --hosts "$tmp/admin-hosts.tsv" --roles site/roles.tsv --checks site/checks.tsv --services site/services.tsv --out "$tmp/staged" --apply > "$tmp/site-config-stage"
grep -q 'status=APPLIED' "$tmp/site-config-stage"
grep -q '^cfg.lab.invalid' "$tmp/staged/host-services.tsv"
if grep -q '^web.lab.invalid' "$tmp/staged/host-services.tsv"; then
    echo "disabled host was staged" >&2
    exit 1
fi
if ./bin/sasd-site-config --hosts "$tmp/admin-hosts.tsv" --roles site/roles.tsv --checks site/checks.tsv --services site/services.tsv --out "$tmp/staged" --apply > "$tmp/site-config-existing" 2>&1; then
    echo "existing staging directory accepted" >&2
    exit 1
fi
grep -q 'output exists' "$tmp/site-config-existing"
./bin/sasd-site-consistency --hosts "$tmp/admin-hosts.tsv" --roles site/roles.tsv --checks site/checks.tsv --services site/services.tsv --monitoring site/monitoring.conf --check > "$tmp/site-consistency"
grep -q 'hosts=3 selections=8 status=OK' "$tmp/site-consistency"
printf 'profile-mismatch\tbaseline\tdisk\t2009\twrong profile\n' > "$tmp/bad-profile-services.tsv"
if ./bin/sasd-site-consistency --hosts site/hosts.tsv --roles site/roles.tsv --checks site/checks.tsv --services "$tmp/bad-profile-services.tsv" --monitoring site/monitoring.conf --check > "$tmp/consistency-error" 2>&1; then
    echo "profile mismatch accepted" >&2
    exit 1
fi
grep -q 'profile mismatch' "$tmp/consistency-error"
printf 'inventory=other.tsv\n' > "$tmp/bad-monitoring.conf"
if ./bin/sasd-site-consistency --hosts site/hosts.tsv --roles site/roles.tsv --checks site/checks.tsv --services site/services.tsv --monitoring "$tmp/bad-monitoring.conf" --check > "$tmp/monitoring-error" 2>&1; then
    echo "monitoring inventory mismatch accepted" >&2
    exit 1
fi
grep -q 'monitoring inventory' "$tmp/monitoring-error"

printf 'one.lab.invalid\t192.0.2.30\tunix\tweb\tlab\tweb\n' > "$tmp/one-host.tsv"
if ./bin/sasd-host-admin --input "$tmp/one-host.tsv" --roles site/roles.tsv --operation remove --host one.lab.invalid --apply > "$tmp/last-remove-error" 2>&1; then
    echo "last active host was removed" >&2
    exit 1
fi
grep -q 'last active host' "$tmp/last-remove-error"
printf 'one.lab.invalid\t192.0.2.30\tunix\tweb\tbad/group\tweb\n' > "$tmp/bad-group.tsv"
if ./bin/sasd-host-admin --input "$tmp/bad-group.tsv" --roles site/roles.tsv --operation validate > "$tmp/bad-group-error" 2>&1; then
    echo "unsafe group accepted" >&2
    exit 1
fi
grep -q 'invalid host group' "$tmp/bad-group-error"
mkdir "$tmp/real-parent"
ln -s "$tmp/real-parent" "$tmp/path-link"
if ./bin/sasd-host-admin --input "$tmp/path-link/hosts.tsv" --roles site/roles.tsv --operation validate > "$tmp/ancestor-error" 2>&1; then
    echo "symlink ancestor accepted" >&2
    exit 1
fi
grep -q 'symlink ancestor' "$tmp/ancestor-error"
echo "R2 site inventory and audit: PASS"
