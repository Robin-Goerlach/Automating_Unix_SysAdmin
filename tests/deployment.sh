#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

stage=$tmp/stage
target=$tmp/target
plan=$tmp/plan
mkdir -m 0700 "$target"
run="$root/bin/sasd-config-deploy --hosts $root/site/hosts.tsv --roles $root/site/roles.tsv --checks $root/site/checks.tsv --services $root/site/services.tsv --staging $stage --target $target --plan $plan"

$run --prepare >/dev/null
$run --dry-run | grep -q 'changes=11 status=DRY-RUN'
test ! -e "$target/.sasd-deploy.lock"

$run --apply | grep -q 'changes=11 status=APPLIED'
test -f "$target/.sasd-deploy.lock"
lock_inode=$(stat -c '%i' "$target/.sasd-deploy.lock")
$run --dry-run >/dev/null
test "$(stat -c '%i' "$target/.sasd-deploy.lock")" = "$lock_inode"
$run --dry-run | grep -q 'changes=0 status=DRY-RUN'

cp "$stage/bigbrother/bb-hosts" "$stage/bigbrother/bb-hosts.save"
printf '%s\n' tampered >> "$stage/bigbrother/bb-hosts"
if $run --dry-run >/dev/null 2>&1; then
    echo "tampered staging accepted" >&2
    exit 1
fi
mv "$stage/bigbrother/bb-hosts.save" "$stage/bigbrother/bb-hosts"

stage2=$tmp/stage2
target2=$tmp/target2
plan2=$tmp/plan2
mkdir -m 0700 "$target2"
run2="$root/bin/sasd-config-deploy --hosts $root/site/hosts.tsv --roles $root/site/roles.tsv --checks $root/site/checks.tsv --services $root/site/services.tsv --staging $stage2 --target $target2 --plan $plan2"
$run2 --prepare >/dev/null
mkdir -p "$target2/site"
printf '%s\n' original > "$target2/site/host-services.tsv"
chmod 0640 "$target2/site/host-services.tsv"
if $run2 --fail-after 1 --apply >/dev/null 2>&1; then
    echo "controlled failure unexpectedly succeeded" >&2
    exit 1
fi
test -f "$target2/site/host-services.tsv"
test ! -e "$target2/bigbrother/bb-hosts"
test -f "$target2/.sasd-deploy.lock"
test "$(cat "$target2/site/host-services.tsv")" = original
test "$(stat -c '%a' "$target2/site/host-services.tsv")" = 640

extra="$stage/bigbrother/extra"
printf '%s\n' unexpected > "$extra"
if $run --dry-run >/dev/null 2>&1; then
    echo "additional staged file accepted" >&2
    exit 1
fi
rm -f "$extra"

if "$root/bin/sasd-config-deploy" --hosts "$root/site/hosts.tsv" --roles "$root/site/roles.tsv" --checks "$root/site/checks.tsv" --services "$root/site/services.tsv" --staging "$stage" --target /etc --plan "$plan" --dry-run >/dev/null 2>&1; then
    echo "system target accepted" >&2
    exit 1
fi

echo "controlled configuration deployment and rollback: PASS"
