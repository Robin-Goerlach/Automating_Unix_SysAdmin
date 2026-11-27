#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT HUP INT TERM
bin/sasd-config-nagios --hosts site/hosts.tsv --roles site/roles.tsv --checks site/checks.tsv --services site/services.tsv > "$tmp/nagios.cfg"
grep -q 'profile=nagios-1.0a7' "$tmp/nagios.cfg"
grep -q 'command_line.*sasd-check-plugin.*--plugin.*sasd-check-adapter' "$tmp/nagios.cfg"
grep -q 'check_command.*sasd-check!disk!fixtures/df/healthy.txt' "$tmp/nagios.cfg"
if grep -q '!none' "$tmp/nagios.cfg"; then
    echo 'Nagios candidate retained an uncontrolled none fixture' >&2; exit 1
fi
grep -q 'define service{' "$tmp/nagios.cfg"
printf 'web.lab.invalid\tdisabled\toperator\n' > "$tmp/state.tsv"
if bin/sasd-config-nagios --hosts site/hosts.tsv --roles site/roles.tsv --checks site/checks.tsv --services site/services.tsv --state "$tmp/state.tsv" | grep -q web.lab.invalid; then
    echo 'disabled host emitted by Nagios adapter' >&2; exit 1
fi
printf 'status web.lab.invalid.http red (1700000000) synthetic critical\n' > "$tmp/status"
if bin/sasd-status-import-nagios --input "$tmp/status" --hosts site/hosts.tsv --roles site/roles.tsv --checks site/checks.tsv --state "$tmp/state.tsv" >/dev/null 2>&1; then
    echo 'disabled Nagios observation accepted' >&2; exit 1
fi
printf 'web.lab.invalid\tenabled\toperator\n' > "$tmp/state-enabled.tsv"
bin/sasd-status-import-nagios --input "$tmp/status" --hosts site/hosts.tsv --roles site/roles.tsv --checks site/checks.tsv --state "$tmp/state-enabled.tsv" > "$tmp/imported"
grep -q "^web.lab.invalid$(printf '\t')http$(printf '\t')red" "$tmp/imported"
printf 'Filesystem 1024-blocks Used Available Capacity Mounted on\n/dev/test 100 20 80 20%% /\n' > "$tmp/df"
rc=0; bin/sasd-check-plugin --plugin bin/sasd-check-adapter --check disk --arg disk --arg web.lab.invalid --arg "$tmp/df" > "$tmp/plugin" || rc=$?
[ "$rc" -eq 0 ]; grep -q '^green.*GREEN -' "$tmp/plugin"
rc=0; bin/sasd-check-plugin --plugin bin/sasd-check-adapter --check sasd --arg disk --arg web.lab.invalid --arg "$tmp/df" > "$tmp/generated-contract" || rc=$?
[ "$rc" -eq 0 ]; grep -q '^green.*GREEN -' "$tmp/generated-contract"
rc=0; bin/sasd-check-plugin --plugin bin/sasd-check-adapter --check sasd --arg disk --arg web.lab.invalid --arg fixtures/df/healthy.txt > "$tmp/warning" || rc=$?
[ "$rc" -eq 1 ]; grep -q '^yellow.*YELLOW - /var utilization 88 percent' "$tmp/warning"
rc=0; bin/sasd-check-plugin --plugin bin/sasd-check-adapter --check sasd --arg disk --arg web.lab.invalid --arg fixtures/df/mixed.txt > "$tmp/critical" || rc=$?
[ "$rc" -eq 2 ]; grep -q '^red.*RED - /var utilization 92 percent' "$tmp/critical"
rc=0; bin/sasd-check-plugin --plugin bin/sasd-check-adapter --check sasd --arg disk --arg web.lab.invalid --arg fixtures/df/invalid.txt > "$tmp/invalid" || rc=$?
[ "$rc" -eq 3 ]; grep -q '^purple.*PURPLE - unparseable df record' "$tmp/invalid"
rc=0; bin/sasd-check-plugin --plugin bin/sasd-check-adapter --check sasd --arg disk --arg web.lab.invalid --arg "$tmp/missing-input" > "$tmp/missing-output" || rc=$?
[ "$rc" -eq 3 ]; grep -q '^purple.*disk fixture is not a regular file' "$tmp/missing-output"
rc=0; bin/sasd-check-plugin --plugin bin/sasd-check-adapter --check http --arg http --arg web.lab.invalid --arg "$tmp/df" > "$tmp/unsupported" || rc=$?
[ "$rc" -eq 3 ]; grep -q '^purple.*not implemented' "$tmp/unsupported"
if bin/sasd-config-nagios --profile 1999 --hosts site/hosts.tsv --roles site/roles.tsv --checks site/checks.tsv --services site/services.tsv >/dev/null 2>&1; then exit 1; fi
echo 'Nagios candidate generation, controlled plugin mapping and synthetic import: PASS'
