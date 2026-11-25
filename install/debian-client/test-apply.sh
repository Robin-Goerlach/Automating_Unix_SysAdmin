#!/bin/sh
set -eu
[ "$(id -u)" -ne 0 ] || { echo 'Fixture apply test SKIPPED: root'; exit 0; }
Here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
root=$(mktemp -d /tmp/sasd-debian-lab.XXXXXXXX)
aux=$(mktemp -d); trap 'rm -rf -- "$root" "$aux"' EXIT HUP INT TERM
chmod 700 "$root"; mkdir -m 700 "$root/etc"
printf 'SASD-DEBIAN-FIXTURE-1\n' > "$root/.sasd-fixture"
printf 'old\n' > "$root/etc/hostname"
printf '# original\n127.0.0.1 localhost\n127.0.1.1 old.lab.invalid old # keep\n::1 localhost ip6-localhost\n192.0.2.22 other.lab.invalid other\n' > "$root/etc/hosts"
printf '# resolver\noptions timeout:2\nnameserver 192.0.2.99\nsearch old.invalid\n' > "$root/etc/resolv.conf"
chmod 640 "$root/etc/hosts"
printf 'dns1=192.0.2.53\ndns2=192.0.2.54\nsearch=lab.invalid\n' > "$aux/site"
run(){ "$Here/apply-baseline.sh" --root="$root" --hostname=node.lab.invalid --site="$aux/site" "$@"; }
hashes(){ (cd "$root" && sha256sum etc/hostname etc/hosts etc/resolv.conf); }
hashes > "$aux/before"
run --dryrun > "$aux/dry"
hashes > "$aux/after"; cmp "$aux/before" "$aux/after"
[ "$(find "$root" -mindepth 1 -maxdepth 1 | wc -l)" -eq 2 ]
run --apply > "$aux/first"
grep -q '^CHANGED hostname$' "$aux/first"
grep -q '^CHANGED hosts$' "$aux/first"
grep -q '^CHANGED resolv.conf$' "$aux/first"
grep -qx '127.0.1.1 node.lab.invalid node # keep' "$root/etc/hosts"
grep -qx '::1 localhost ip6-localhost' "$root/etc/hosts"
grep -qx '192.0.2.22 other.lab.invalid other' "$root/etc/hosts"
grep -qx 'options timeout:2' "$root/etc/resolv.conf"
[ "$(stat -c %a "$root/etc/hosts")" = 640 ]
backup=$(sed -n 's/^FIXTURE ONLY; backup=//p' "$aux/first")
(cd "$backup" && sha256sum hostname hosts resolv.conf) | sed 's/  /  etc\//' > "$aux/backup-hashes"
cmp "$aux/before" "$aux/backup-hashes"
hashes > "$aux/installed"
run --apply > "$aux/second"
[ "$(grep -c '^UNCHANGED ' "$aux/second")" -eq 3 ]
hashes > "$aux/after"; cmp "$aux/installed" "$aux/after"
# Conflict, symlink, hardlink, busy lock, and real root must fail closed.
expect2(){ rc=0; "$@" > "$aux/reject" 2>&1 || rc=$?; [ "$rc" -eq 2 ]; }
cp "$root/etc/hosts" "$aux/hosts"
printf '192.0.2.23 node.lab.invalid node\n' >> "$root/etc/hosts"
hashes > "$aux/conflict"; expect2 run --apply; hashes > "$aux/after"; cmp "$aux/conflict" "$aux/after"
cp "$aux/hosts" "$root/etc/hosts"
mv "$root/etc/resolv.conf" "$aux/resolv"; ln -s "$aux/resolv" "$root/etc/resolv.conf"
expect2 run --apply; [ -L "$root/etc/resolv.conf" ]; rm "$root/etc/resolv.conf"; mv "$aux/resolv" "$root/etc/resolv.conf"
ln "$root/etc/hostname" "$aux/hardlink"; expect2 run --apply; rm "$aux/hardlink"
mkdir "$root/.baseline-lock"; expect2 run --apply; rmdir "$root/.baseline-lock"
expect2 "$Here/apply-baseline.sh" --root=/ --hostname=node.lab.invalid --site="$aux/site" --apply
# Induce post-commit verification failure in an isolated copy, not production code.
mkdir "$aux/copy"; cp -R "$Here/lib" "$aux/copy/"; cp "$Here/apply-baseline.sh" "$aux/copy/"
cat > "$aux/copy/verify-baseline.sh" <<'VERIFY'
#!/bin/sh
case "$1" in */check) exit 0 ;; *) exit 1 ;; esac
VERIFY
chmod +x "$aux/copy/verify-baseline.sh"
hashes > "$aux/pre-failure"
rc=0; "$aux/copy/apply-baseline.sh" --root="$root" --hostname=next.lab.invalid --site="$aux/site" --apply > "$aux/failure" 2>&1 || rc=$?
[ "$rc" -ne 0 ]; grep -q 'ROLLED BACK: hostname' "$aux/failure"; grep -q 'ROLLED BACK: hosts' "$aux/failure"
hashes > "$aux/after"; cmp "$aux/pre-failure" "$aux/after"
[ ! -e "$root/.baseline-lock" ]
echo 'Fixture baseline apply tests passed'
