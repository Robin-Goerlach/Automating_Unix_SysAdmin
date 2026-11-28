#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT HUP INT TERM
bin/sasd-config-nagios --hosts site/hosts.tsv --roles site/roles.tsv --checks site/checks.tsv --services site/services.tsv > "$tmp/nagios.cfg"
grep -q 'profile=nagios-1.0a7' "$tmp/nagios.cfg"
grep -q 'command_line.*sasd-check-plugin.*--plugin.*sasd-check-adapter' "$tmp/nagios.cfg"
nagios() {
    bin/sasd-config-nagios --hosts site/hosts.tsv --roles site/roles.tsv \
        --checks site/checks.tsv --services site/services.tsv "$@"
}
for target in filesystem - web; do
    rc=0
    perl tests/classic-candidate-command.pl "$tmp/nagios.cfg" web.lab.invalid "$target" > "$tmp/default" || rc=$?
    [ "$rc" -eq 3 ]
    grep -q '^purple.*source=UNKNOWN' "$tmp/default"
done
grep -q 'check_command.*sasd-check!conn!-' "$tmp/nagios.cfg"
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
nagios --disk-fixture "$tmp/df" --fixture-host web.lab.invalid > "$tmp/fixture.cfg"
perl tests/classic-candidate-command.pl "$tmp/fixture.cfg" web.lab.invalid filesystem > "$tmp/selected"
grep -q '^green.*GREEN - source=FIXTURE / utilization 20 percent' "$tmp/selected"
for target in 'mail.lab.invalid filesystem' 'web.lab.invalid -'; do
    set -- $target
    rc=0
    perl tests/classic-candidate-command.pl "$tmp/fixture.cfg" "$1" "$2" > "$tmp/unselected" || rc=$?
    [ "$rc" -eq 3 ]
    grep -q '^purple.*source=UNKNOWN' "$tmp/unselected"
done
cp "$tmp/df" "$tmp/df ! bad"
if nagios --disk-fixture "$tmp/df ! bad" --fixture-host web.lab.invalid > "$tmp/unsafe" 2>&1 ||
   nagios --disk-fixture "$tmp/df" > "$tmp/unbound" 2>&1 ||
   nagios --disk-fixture "$tmp/df" --fixture-host web.lab.invalid --state "$tmp/state.tsv" > "$tmp/disabled" 2>&1; then
    echo 'unsafe, unbound or disabled Nagios fixture accepted' >&2; exit 1
fi

check_disk() {
    expected=$1
    pattern=$2
    shift 2
    rc=0
    bin/sasd-check-plugin --plugin bin/sasd-check-adapter --check sasd "$@" > "$tmp/disk-result" || rc=$?
    [ "$rc" -eq "$expected" ]
    grep -q "$pattern" "$tmp/disk-result"
}
check_disk 1 '^yellow.*YELLOW - source=FIXTURE /var utilization 88 percent' --arg disk --arg web.lab.invalid --arg fixtures/df/healthy.txt
check_disk 2 '^red.*RED - source=FIXTURE /var utilization 92 percent' --arg disk --arg web.lab.invalid --arg fixtures/df/mixed.txt
check_disk 0 '^green.*source=OFFLINE' --arg --offline --arg disk --arg web.lab.invalid --arg "$tmp/df"
check_disk 3 '^purple.*unparseable df record' --arg disk --arg web.lab.invalid --arg fixtures/df/invalid.txt
check_disk 3 '^purple.*not implemented' --arg http --arg web.lab.invalid --arg "$tmp/df"
check_disk 3 '^purple.*expected check' --arg disk --arg web.lab.invalid
check_disk 3 '^purple.*expected check' --arg disk --arg web.lab.invalid --arg "$tmp/df" --arg extra
check_disk 3 '^purple.*disk input' --arg disk --arg web.lab.invalid --arg "$tmp/missing"
check_disk 3 '^purple.*disk input' --arg disk --arg web.lab.invalid --arg "$tmp"
ln -s "$tmp/df" "$tmp/link"
check_disk 3 '^purple.*disk input' --arg disk --arg web.lab.invalid --arg "$tmp/link"
: > "$tmp/empty"
head -n 1 "$tmp/df" > "$tmp/header"
for file in empty header; do
    check_disk 3 '^purple.*no filesystem records' --arg disk --arg web.lab.invalid --arg "$tmp/$file"
done
printf '/dev/test bad 20 80 20%% /\n/dev/bad 100 20 80 20%% / extra\n' > "$tmp/damaged"
check_disk 3 '^purple.*unparseable df record' --arg disk --arg web.lab.invalid --arg "$tmp/damaged"
cat "$tmp/damaged" >> "$tmp/df"
check_disk 3 '^purple.*unparseable df record' --arg disk --arg web.lab.invalid --arg "$tmp/df"
if [ "$(id -u)" -ne 0 ]; then
    chmod 000 "$tmp/df"
    check_disk 3 '^purple.*disk input' --arg disk --arg web.lab.invalid --arg "$tmp/df"
fi
if bin/sasd-config-nagios --profile 1999 --hosts site/hosts.tsv --roles site/roles.tsv --checks site/checks.tsv --services site/services.tsv >/dev/null 2>&1; then exit 1; fi
echo 'Nagios candidate generation, controlled plugin mapping and synthetic import: PASS'
