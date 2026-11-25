#!/bin/sh
set -eu
[ "$(id -u)" -ne 0 ] || { echo 'Interruption test SKIPPED: root'; exit 0; }
Here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
. "$Here/lib/transaction.sh"
root=$(mktemp -d /tmp/sasd-debian-lab.XXXXXXXX)
aux=$(mktemp -d); trap 'rm -rf -- "$root" "$aux"' EXIT
umask 077
mkdir "$root/etc"
printf 'SASD-DEBIAN-FIXTURE-1\n' > "$root/.sasd-fixture"
printf 'old\n' > "$root/etc/hostname"
printf '127.0.0.1 localhost\n127.0.1.1 old.lab.invalid old\n::1 localhost\n' > "$root/etc/hosts"
printf 'nameserver 192.0.2.99\nsearch old.invalid\n' > "$root/etc/resolv.conf"
printf 'dns1=192.0.2.53\nsearch=lab.invalid\n' > "$aux/site"
fixture_check
before=$(manifest "$root/etc")
run(){ "$Here/apply-baseline.sh" --root="$root" --hostname=node.lab.invalid --site="$aux/site" "$@"; }
run --dryrun > /dev/null; [ "$(manifest "$root/etc")" = "$before" ]
# Inject SIGKILL from the final verification hook of an isolated script copy.
mkdir "$aux/copy"; cp -R "$Here/lib" "$aux/copy/"; cp "$Here/apply-baseline.sh" "$aux/copy/"
cat > "$aux/copy/verify-baseline.sh" <<'VERIFY'
#!/bin/sh
case "$1" in */check) exit 0 ;; *) kill -KILL "$PPID" ;; esac
VERIFY
chmod +x "$aux/copy/verify-baseline.sh"
rc=0; "$aux/copy/apply-baseline.sh" --root="$root" --hostname=node.lab.invalid --site="$aux/site" --apply > "$aux/killed" 2>&1 || rc=$?
[ "$rc" -eq 137 ]; [ "$(manifest "$root/etc")" != "$before" ]
work=$(pending_transaction); [ -n "$work" ]; [ "$(state_get "$work")" = APPLYING ]
rc=0; run --apply > "$aux/blocked" 2>&1 || rc=$?; [ "$rc" -eq 2 ]; grep -q 'recovery required' "$aux/blocked"
"$Here/recover-baseline.sh" --root="$root" --transaction="${work##*/}" --apply
[ "$(manifest "$root/etc")" = "$before" ]
run --apply > "$aux/success"; grep -q '^CHANGED hostname$' "$aux/success"
installed=$(manifest "$root/etc"); [ -z "$(pending_transaction)" ]
run --apply > "$aux/again"; [ "$(grep -c '^UNCHANGED ' "$aux/again")" -eq 3 ]; [ "$(manifest "$root/etc")" = "$installed" ]
echo 'Actual process interruption and reapply tests passed'
