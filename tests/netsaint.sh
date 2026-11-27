#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT HUP INT TERM
bin/sasd-config-netsaint --hosts site/hosts.tsv --roles site/roles.tsv --checks site/checks.tsv --services site/services.tsv > "$tmp/hosts.cfg"
grep -q '^define host{' "$tmp/hosts.cfg"
grep -q 'check-sasd!http' "$tmp/hosts.cfg"
grep -q 'hostgroup_name[[:space:]]*role_lab' "$tmp/hosts.cfg"
printf 'web.lab.invalid\tdisabled\toperator\n' > "$tmp/state.tsv"
if bin/sasd-config-netsaint --hosts site/hosts.tsv --roles site/roles.tsv --checks site/checks.tsv --services site/services.tsv --state "$tmp/state.tsv" | grep -q web.lab.invalid; then
    echo 'disabled host emitted by NetSaint adapter' >&2; exit 1
fi
printf 'status web.lab.invalid.http yellow (1700000000) synthetic warning\n' > "$tmp/status"
bin/sasd-status-import-netsaint --input "$tmp/status" --hosts site/hosts.tsv --roles site/roles.tsv --checks site/checks.tsv > "$tmp/imported"
grep -q "^web.lab.invalid$(printf '\t')http$(printf '\t')yellow" "$tmp/imported"
if printf 'status web.lab.invalid.http green ok\nstatus web.lab.invalid.http red duplicate\n' > "$tmp/duplicate" && bin/sasd-status-import-netsaint --input "$tmp/duplicate" --hosts site/hosts.tsv --roles site/roles.tsv --checks site/checks.tsv >/dev/null 2>&1; then
    echo 'duplicate NetSaint observation accepted' >&2; exit 1
fi
printf '#!/bin/sh\nprintf "plugin output\\n"\nexit 1\n' > "$tmp/plugin"; chmod 700 "$tmp/plugin"
rc=0; bin/sasd-check-plugin --plugin "$tmp/plugin" --check disk > "$tmp/plugin.out" || rc=$?
[ "$rc" -eq 1 ]
grep -q '^yellow[[:space:]]' "$tmp/plugin.out"
printf 'status web.lab.invalid.http blue bad\n' > "$tmp/bad"
if bin/sasd-status-import-netsaint --input "$tmp/bad" --hosts site/hosts.tsv --roles site/roles.tsv --checks site/checks.tsv >/dev/null 2>&1; then exit 1; fi
echo 'NetSaint candidate generation, status adapter and check interface: PASS'
