#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
task_tmp=$(mktemp -d)
trap 'rm -rf "$task_tmp"' EXIT HUP INT TERM

bin/sasd-config-cfengine2 --hosts site/hosts.tsv --roles site/roles.tsv --version 2.0 --dry-run > "$task_tmp/dry"
grep -q 'profile=2.0 hosts=4 status=DRY-RUN' "$task_tmp/dry"
bin/sasd-config-cfengine2 --hosts site/hosts.tsv --roles site/roles.tsv --version 2.1 --out "$task_tmp/candidate.conf" --apply > "$task_tmp/apply"
grep -q 'actionsequence = ( files )' "$task_tmp/candidate.conf"
grep -q 'sasd-cfengine2-web.lab.invalid-web-marker mode=644 action=warn' "$task_tmp/candidate.conf"
printf 'web.lab.invalid\tdisabled\toperator\n' > "$task_tmp/state.tsv"
bin/sasd-config-cfengine2 --hosts site/hosts.tsv --roles site/roles.tsv --state "$task_tmp/state.tsv" --out "$task_tmp/disabled.conf" --apply >/dev/null
if grep -q 'sasd-cfengine2-web.lab.invalid' "$task_tmp/disabled.conf"; then
    echo "disabled host emitted to CFEngine 2 candidate" >&2
    exit 1
fi
if bin/sasd-config-cfengine2 --hosts site/hosts.tsv --roles site/roles.tsv --version 3.0 --dry-run > "$task_tmp/version-error" 2>&1; then
    echo "unsupported CFEngine 2 version accepted" >&2
    exit 1
fi
grep -q 'unsupported CFEngine 2 version profile' "$task_tmp/version-error"
if bin/sasd-config-cfengine2 --hosts site/hosts.tsv --roles site/roles.tsv --state "$task_tmp/missing.tsv" --dry-run > "$task_tmp/missing-error" 2>&1; then
    echo "missing explicit state accepted" >&2
    exit 1
fi
grep -q 'host state file is missing' "$task_tmp/missing-error"
if bin/sasd-config-cfengine2 --hosts site/hosts.tsv --roles site/roles.tsv --out site/hosts.tsv --apply > "$task_tmp/input-overwrite-error" 2>&1; then
    echo "CFEngine 2 input overwrite was accepted" >&2; exit 1
fi
grep -q 'output path overlaps an input file' "$task_tmp/input-overwrite-error"
echo "CFEngine 2 candidate generation: PASS"
