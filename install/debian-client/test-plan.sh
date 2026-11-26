#!/bin/sh
# Test the real catalog, and isolated malformed variants without invoking tasks.
set -eu
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
repo=$(CDPATH= cd -- "$here/../.." && pwd)
tmp=$(mktemp -d); trap 'rm -rf -- "$tmp"' EXIT HUP INT TERM
printf 'workstation\tsite_workstation\tmodern\troles/workstation.tsv\n' > "$tmp/roles.tsv"
printf 'node.lab.invalid\t192.0.2.40\tdebian\tworkstation\t\tbaseline\n' > "$tmp/hosts.tsv"
plan(){ perl "$here/plan-client.pl" --inventory="$tmp/hosts.tsv" --roles="$tmp/roles.tsv" --hostname=node.lab.invalid "$@"; }
reject(){ if "$@" > "$tmp/rejected" 2>&1; then echo 'unexpected successful plan' >&2; exit 1; fi; }
plan > "$tmp/full"
count=$(awk 'END{print NR-1}' "$here/checklist.tsv")
[ "$(awk 'END{print NR-3}' "$tmp/full")" -eq "$count" ]
plan --only=0040 > "$tmp/selected"
[ "$(awk 'END{print NR-3}' "$tmp/selected")" -eq 2 ]
awk -F '\t' '$1=="0030" && $4=="PLAN_CANDIDATE" {a=1} $1=="0040" && $4=="PLAN_CANDIDATE" && $5=="0030:candidate" {b=1} END{exit !(a&&b)}' "$tmp/selected"
plan --only=0020 > "$tmp/wait"
awk -F '\t' '$1=="0020" && $4=="WAIT_VERIFIED" && $5=="0010:verified" {ok=1} END{exit !ok}' "$tmp/wait"
reject plan --only=9999
reject plan --hostname=other.lab.invalid
reject perl "$here/plan-client.pl" --inventory="$tmp/hosts.tsv" --roles="$tmp/roles.tsv" --hostname=other.lab.invalid
cp "$tmp/hosts.tsv" "$tmp/good-hosts"
printf 'NODE.lab.invalid\t192.0.2.41\tdebian\tworkstation\t\tbaseline\n' >> "$tmp/hosts.tsv"; reject plan
cp "$tmp/good-hosts" "$tmp/hosts.tsv"
printf 'other.lab.invalid\t192.0.2.40\tdebian\tworkstation\t\tbaseline\n' >> "$tmp/hosts.tsv"; reject plan
sed 's/192.0.2.40/192.0.2.040/' "$tmp/good-hosts" > "$tmp/hosts.tsv"; reject plan
sed 's/\tdebian\t/\tunix\t/' "$tmp/good-hosts" > "$tmp/hosts.tsv"; reject plan
sed 's/	baseline$/	server/' "$tmp/good-hosts" > "$tmp/hosts.tsv"; reject plan
cp "$tmp/good-hosts" "$tmp/hosts.tsv"
# Copy only the planner and its trusted dependencies to an isolated repository layout.
mkdir -p "$tmp/copy/install/debian-client" "$tmp/copy/bin"
cp "$repo/bin/sasd-site-inventory" "$tmp/copy/bin/"
mkdir -p "$tmp/copy/lib/SASD"
cp "$repo/lib/SASD/Monitor.pm" "$tmp/copy/lib/SASD/"
copy="$tmp/copy/install/debian-client"
cp "$here/plan-client.pl" "$here/checklist.tsv" "$here/dependencies.tsv" "$copy/"
cp -R "$here/tasks" "$copy/"
fixture(){ perl "$copy/plan-client.pl" --inventory="$tmp/hosts.tsv" --roles="$tmp/roles.tsv" --hostname=node.lab.invalid; }
fixture > /dev/null
mv "$tmp/copy/lib/SASD/Monitor.pm" "$tmp/saved-monitor"
reject fixture
grep -q 'R2 inventory module unavailable' "$tmp/rejected"
mv "$tmp/saved-monitor" "$tmp/copy/lib/SASD/Monitor.pm"
cp "$copy/dependencies.tsv" "$tmp/good-deps"
printf '0030\t0040\tcandidate\n' >> "$copy/dependencies.tsv"; reject fixture
cp "$tmp/good-deps" "$copy/dependencies.tsv"
printf '0040\t9999\tverified\n' >> "$copy/dependencies.tsv"; reject fixture
cp "$tmp/good-deps" "$copy/dependencies.tsv"
printf '0040\t0030\tcandidate\n' >> "$copy/dependencies.tsv"; reject fixture
cp "$tmp/good-deps" "$copy/dependencies.tsv"
# Test a non-renderable prerequisite using an isolated catalog mutation.
# Task 0020 now renders a review policy; its real catalog must remain intact.
cp "$copy/checklist.tsv" "$tmp/good-catalog"
awk -F '\t' 'BEGIN{OFS="\t"} $1=="0020" {$4="review"; $5="-"} {print}' "$tmp/good-catalog" > "$copy/checklist.tsv"
printf '0030\t0020\tcandidate\n' >> "$copy/dependencies.tsv"; reject fixture
cp "$tmp/good-catalog" "$copy/checklist.tsv"
# With the real catalog restored, the same edge is valid but waits on 0020.
fixture > "$tmp/candidate-wait"
awk -F '\t' '$1=="0030" && $4=="WAIT_CANDIDATE" {ok=1} END{exit !ok}' "$tmp/candidate-wait"
cp "$tmp/good-deps" "$copy/dependencies.tsv"
printf '0040\t0010\tverified\n' >> "$copy/dependencies.tsv"
printf '0800\t0040\tcandidate\n' >> "$copy/dependencies.tsv"
fixture > "$tmp/blocked"
awk -F '\t' '$1=="0040" && $4=="WAIT_VERIFIED" {a=1} $1=="0800" && $4=="WAIT_CANDIDATE" {b=1} END{exit !(a&&b)}' "$tmp/blocked"
cp "$tmp/good-deps" "$copy/dependencies.tsv"
# The planner must not execute even a failing task script.
printf '#!/bin/sh\nexit 99\n' > "$copy/tasks/0030_Host_Set_Name"
fixture > /dev/null
mv "$copy/tasks/0030_Host_Set_Name" "$tmp/saved-task"; reject fixture
ln -s "$tmp/saved-task" "$copy/tasks/0030_Host_Set_Name"; reject fixture
rm "$copy/tasks/0030_Host_Set_Name"; mv "$tmp/saved-task" "$copy/tasks/0030_Host_Set_Name"
touch "$copy/tasks/9999_Extra"; reject fixture
printf 'Client plan tests passed (catalog rows=%s)\n' "$count"
