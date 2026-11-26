#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
task_tmp=$(mktemp -d)
trap 'rm -rf "$task_tmp"' EXIT HUP INT TERM
bin/sasd-config-cfengine1 --hosts site/hosts.tsv --roles site/roles.tsv --dry-run > "$task_tmp/dry"
grep -q 'profile=1999 hosts=4 status=DRY-RUN' "$task_tmp/dry"
bin/sasd-config-cfengine1 --hosts site/hosts.tsv --roles site/roles.tsv --out "$task_tmp/candidate.conf" --apply > "$task_tmp/apply"
grep -q 'actionsequence = ( files )' "$task_tmp/candidate.conf"
grep -q '/tmp/sasd-cfengine-web.lab.invalid-web-marker mode=644 action=warn' "$task_tmp/candidate.conf"
printf 'web.lab.invalid\tdisabled\toperator\n' > "$task_tmp/state.tsv"
bin/sasd-config-cfengine1 --hosts site/hosts.tsv --roles site/roles.tsv --state "$task_tmp/state.tsv" --out "$task_tmp/disabled.conf" --apply >/dev/null
if grep -q 'web.lab.invalid-web-marker' "$task_tmp/disabled.conf"; then
    echo "disabled host emitted to CFEngine candidate" >&2; exit 1
fi
if bin/sasd-config-cfengine1 --hosts site/hosts.tsv --roles site/roles.tsv --profile 2009 --dry-run > "$task_tmp/profile-error" 2>&1; then
    echo "wrong CFEngine profile accepted" >&2; exit 1
fi
grep -q 'profile is 1999' "$task_tmp/profile-error"
if bin/sasd-config-cfengine1 --hosts site/hosts.tsv --roles site/roles.tsv --out site/hosts.tsv --apply > "$task_tmp/input-overwrite-error" 2>&1; then
    echo "CFEngine 1 input overwrite was accepted" >&2; exit 1
fi
grep -q 'output path overlaps an input file' "$task_tmp/input-overwrite-error"
echo "CFEngine 1 candidate generation: PASS"
