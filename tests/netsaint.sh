#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT HUP INT TERM
bin/sasd-config-netsaint --hosts site/hosts.tsv --roles site/roles.tsv --checks site/checks.tsv --services site/services.tsv > "$tmp/hosts.cfg"
grep -q '^define host{' "$tmp/hosts.cfg"
grep -q 'check-sasd!http' "$tmp/hosts.cfg"
grep -q 'command_line.*sasd-check-plugin.*--plugin.*sasd-check-adapter' "$tmp/hosts.cfg"
grep -q 'hostgroup_name[[:space:]]*role_lab' "$tmp/hosts.cfg"
netsaint() {
    bin/sasd-config-netsaint --hosts site/hosts.tsv --roles site/roles.tsv \
        --checks site/checks.tsv --services site/services.tsv "$@"
}
rc=0
perl tests/classic-candidate-command.pl "$tmp/hosts.cfg" web.lab.invalid filesystem > "$tmp/no-source" || rc=$?
[ "$rc" -eq 3 ]
grep -q '^purple.*source=UNKNOWN no disk observation configured' "$tmp/no-source"
for case in 'healthy 1 YELLOW' 'critical 2 RED' 'invalid 3 PURPLE' 'ok 0 GREEN'; do
    set -- $case
    input="$tmp/observation"
    if [ "$1" = ok ]; then
        printf 'Filesystem 1024-blocks Used Available Capacity Mounted on\n/dev/test 100 20 80 20%% /\n' > "$input"
    else
        cp "fixtures/df/$1.txt" "$input"
    fi
    netsaint --disk-fixture "$input" --fixture-host web.lab.invalid > "$tmp/fixture.cfg"
    rc=0
    perl tests/classic-candidate-command.pl "$tmp/fixture.cfg" web.lab.invalid filesystem > "$tmp/result" || rc=$?
    [ "$rc" -eq "$2" ]
    grep -q "$3 - source=FIXTURE" "$tmp/result"
done
mv "$tmp/observation" "$tmp/observation-moved"
rc=0
perl tests/classic-candidate-command.pl "$tmp/fixture.cfg" web.lab.invalid filesystem > "$tmp/missing" || rc=$?
[ "$rc" -eq 3 ]
grep -q '^purple.*source=UNKNOWN disk input' "$tmp/missing"
printf 'web.lab.invalid\tdisabled\toperator\n' > "$tmp/state.tsv"
if bin/sasd-config-netsaint --hosts site/hosts.tsv --roles site/roles.tsv --checks site/checks.tsv --services site/services.tsv --state "$tmp/state.tsv" | grep -q web.lab.invalid; then
    echo 'disabled host emitted by NetSaint adapter' >&2; exit 1
fi
printf 'status web.lab.invalid.http yellow (1700000000) synthetic warning\n' > "$tmp/status"
if bin/sasd-status-import-netsaint --input "$tmp/status" --hosts site/hosts.tsv --roles site/roles.tsv --checks site/checks.tsv --state "$tmp/state.tsv" > "$tmp/imported" 2> "$tmp/lifecycle-error"; then
    echo 'status for disabled host accepted' >&2; exit 1
fi
printf 'web.lab.invalid\tenabled\toperator\n' > "$tmp/state-enabled.tsv"
bin/sasd-status-import-netsaint --input "$tmp/status" --hosts site/hosts.tsv --roles site/roles.tsv --checks site/checks.tsv --state "$tmp/state-enabled.tsv" > "$tmp/imported"
grep -q "^web.lab.invalid$(printf '\t')http$(printf '\t')yellow" "$tmp/imported"
if printf 'status web.lab.invalid.http green ok\nstatus web.lab.invalid.http red duplicate\n' > "$tmp/duplicate" && bin/sasd-status-import-netsaint --input "$tmp/duplicate" --hosts site/hosts.tsv --roles site/roles.tsv --checks site/checks.tsv >/dev/null 2>&1; then
    echo 'duplicate NetSaint observation accepted' >&2; exit 1
fi
printf '#!/bin/sh\nprintf "plugin output\\n"\nexit 1\n' > "$tmp/plugin"; chmod 700 "$tmp/plugin"
rc=0; bin/sasd-check-plugin --plugin "$tmp/plugin" --check disk > "$tmp/plugin.out" || rc=$?
[ "$rc" -eq 1 ]
grep -q '^yellow[[:space:]]' "$tmp/plugin.out"
for state in 0 1 2 3; do
    printf '#!/bin/sh\nprintf "state %s"\nexit %s\n' "$state" "$state" > "$tmp/state-$state"
    chmod 700 "$tmp/state-$state"
    rc=0; bin/sasd-check-plugin --plugin "$tmp/state-$state" --check disk > "$tmp/state-$state.out" || rc=$?
    [ "$rc" -eq "$state" ]
done
printf '#!/bin/sh\nexec 1>&-\nexec 2>&-\nsleep 2\n' > "$tmp/closed-plugin"; chmod 700 "$tmp/closed-plugin"
start=$(date +%s); rc=0; bin/sasd-check-plugin --plugin "$tmp/closed-plugin" --check disk --timeout 1 > "$tmp/closed.out" || rc=$?; elapsed=$(($(date +%s)-start))
[ "$rc" -eq 3 ] && [ "$elapsed" -le 3 ]
printf '#!/bin/sh\n( trap : TERM; sleep 5 ) &\nexec 1>&-\nexec 2>&-\nwait\n' > "$tmp/descendant-plugin"; chmod 700 "$tmp/descendant-plugin"
rc=0; bin/sasd-check-plugin --plugin "$tmp/descendant-plugin" --check disk --timeout 1 > "$tmp/descendant.out" || rc=$?
[ "$rc" -eq 3 ]
printf '#!/bin/sh\ntrap : TERM\nsleep 5\n' > "$tmp/term-ignore-plugin"; chmod 700 "$tmp/term-ignore-plugin"
rc=0; bin/sasd-check-plugin --plugin "$tmp/term-ignore-plugin" --check disk --timeout 1 > "$tmp/term-ignore.out" || rc=$?
[ "$rc" -eq 3 ]
printf '#!/bin/sh\nprintf "no\\000control\\001bytes"\nexit 0\n' > "$tmp/control-plugin"; chmod 700 "$tmp/control-plugin"
bin/sasd-check-plugin --plugin "$tmp/control-plugin" --check disk > "$tmp/control.out"
! grep -q '[[:cntrl:]]' "$tmp/control.out"
printf '#!/bin/sh\nprintf "arg=%%s" "$1"\nexit 0\n' > "$tmp/space name; harmless"
chmod 700 "$tmp/space name; harmless"
bin/sasd-check-plugin --plugin "$tmp/space name; harmless" --check disk --arg 'value with spaces' > "$tmp/space.out"
grep -q 'arg=value with spaces' "$tmp/space.out"
if bin/sasd-check-plugin --plugin "$tmp/missing" --check disk >/dev/null 2>&1; then exit 1; fi
printf '#!/bin/sh\nexit 0\n' > "$tmp/not-executable"; chmod 600 "$tmp/not-executable"
if bin/sasd-check-plugin --plugin "$tmp/not-executable" --check disk >/dev/null 2>&1; then exit 1; fi
printf '#!/bin/sh\nprintf "unknown output\\n" >&2\nexit 3\n' > "$tmp/unknown-plugin"; chmod 700 "$tmp/unknown-plugin"
rc=0; bin/sasd-check-plugin --plugin "$tmp/unknown-plugin" --check disk > "$tmp/unknown.out" || rc=$?
[ "$rc" -eq 3 ]
grep -q '^purple[[:space:]]unknown output' "$tmp/unknown.out"
printf '#!/bin/sh\nsleep 5\n' > "$tmp/slow-plugin"; chmod 700 "$tmp/slow-plugin"
rc=0; bin/sasd-check-plugin --plugin "$tmp/slow-plugin" --check disk --timeout 1 > "$tmp/timeout.out" || rc=$?
[ "$rc" -eq 3 ]
grep -q '^purple[[:space:]]plugin timeout$' "$tmp/timeout.out"
printf '#!/bin/sh\nhead -c 4097 /dev/zero\n' > "$tmp/large-plugin"; chmod 700 "$tmp/large-plugin"
rc=0; bin/sasd-check-plugin --plugin "$tmp/large-plugin" --check disk > "$tmp/large.out" || rc=$?
[ "$rc" -eq 3 ]
grep -q '^purple[[:space:]]plugin output exceeded 4096 bytes$' "$tmp/large.out"
printf 'status web.lab.invalid.http blue bad\n' > "$tmp/bad"
if bin/sasd-status-import-netsaint --input "$tmp/bad" --hosts site/hosts.tsv --roles site/roles.tsv --checks site/checks.tsv >/dev/null 2>&1; then exit 1; fi
echo 'NetSaint candidate generation, status adapter and check interface: PASS'
