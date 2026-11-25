#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT HUP INT TERM
profile_file="$tmp/profiles.tsv"
printf 'img1\t1.0\t%s\tfile:///lab/web.tar\n' "$(printf 'image-fixture\n' | sha256sum | awk '{print $1}')" > "$tmp/images.tsv"
printf 'web-lab\tLinux\t%s\timage\tfile:///lab/web.tar\timg1\tweb\trootfs\tpostinstall.sh\tweb\n' "$(uname -m)" > "$profile_file"
printf 'bad-lab\tLinux\t%s\timage\tpassword=bad\timg1\tweb\trootfs\tpostinstall.sh\tweb\n' "$(uname -m)" >> "$profile_file"

bin/sasd-postinstall --root "$tmp/dry" --profile-file "$profile_file" --images "$tmp/images.tsv" --image-version 1.0 --profile web-lab --host client-a.lab.invalid --expires-at 2000000000 --dry-run > "$tmp/dry.log"
grep -q 'identity=generate-new' "$tmp/dry.log"
test ! -e "$tmp/dry"
bin/sasd-postinstall --root "$tmp/client-a" --profile-file "$profile_file" --images "$tmp/images.tsv" --image-version 1.0 --profile web-lab --host client-a.lab.invalid --expires-at 2000000000 --apply > "$tmp/a.log"
test -f "$tmp/client-a/etc/identity"; test -f "$tmp/client-a/var/enrollment.request"
grep -q 'client-a.lab.invalid' "$tmp/client-a/etc/hostname"

bin/sasd-postinstall --root "$tmp/client-b" --profile-file "$profile_file" --images "$tmp/images.tsv" --image-version 1.0 --profile web-lab --host client-b.lab.invalid --expires-at 2000000000 --apply > "$tmp/b.log"
fingerprint_a=$(ssh-keygen -lf "$tmp/client-a/etc/identity.pub" -E sha256 | awk '{print $2}')
fingerprint_b=$(ssh-keygen -lf "$tmp/client-b/etc/identity.pub" -E sha256 | awk '{print $2}')
test "$fingerprint_a" != "$fingerprint_b"
if bin/sasd-postinstall --root "$tmp/stale" --profile-file "$profile_file" --images "$tmp/images.tsv" --image-version 0.9 --profile web-lab --host stale.lab.invalid --expires-at 2000000000 --dry-run >/dev/null 2>&1; then echo "stale image accepted" >&2; exit 1; fi

if bin/sasd-postinstall --root "$tmp/bad" --profile-file "$profile_file" --images "$tmp/images.tsv" --profile bad-lab --host client-c.lab.invalid --expires-at 2000000000 --dry-run >/dev/null 2>&1; then echo "secret profile accepted" >&2; exit 1; fi
cp -a "$tmp/client-a" "$tmp/clone"
if bin/sasd-postinstall --root "$tmp/clone" --profile-file "$profile_file" --images "$tmp/images.tsv" --profile web-lab --host client-clone.lab.invalid --expires-at 2000000000 --apply >/dev/null 2>&1; then echo "identity clone accepted" >&2; exit 1; fi

server="$tmp/server"
install/install-monitoring-server.sh --prefix "$server" --config site/monitoring.conf --apply >/dev/null
"$server/bin/sasd-enrollment" --dir "$server/var/enrollment" --action import-request --request "$tmp/client-a/var/enrollment.request" >/dev/null
"$server/bin/sasd-enrollment" --dir "$server/var/enrollment" --action approve --host client-a.lab.invalid --operator admin --at 1000 >/dev/null
printf 'client-a.lab.invalid\tdisk\tgreen\tpostinstall healthy\n' > "$tmp/a-status.tsv"
"$tmp/client-a/bin/sasd-node-status" --host client-a.lab.invalid --key "$tmp/client-a/etc/identity" --sequence 1 --sent-at 1000 --input "$tmp/a-status.tsv" --out "$tmp/a.payload" >/dev/null
"$server/bin/sasd-monitor-auth-import" --config "$server/etc/sasd-monitor.conf" --input "$tmp/a.payload" --signature "$tmp/a.payload.sig" --now 1050 >/dev/null
grep -q 'client-a.lab.invalid' "$server/var/status/latest"/*

"$server/bin/sasd-enrollment" --dir "$server/var/enrollment" --action import-request --request "$tmp/client-b/var/enrollment.request" >/dev/null
"$server/bin/sasd-enrollment" --dir "$server/var/enrollment" --action reject --host client-b.lab.invalid --operator admin --at 1000 >/dev/null
printf 'client-b.lab.invalid\tdisk\tgreen\trejected\n' > "$tmp/b-status.tsv"
"$tmp/client-b/bin/sasd-node-status" --host client-b.lab.invalid --key "$tmp/client-b/etc/identity" --sequence 1 --sent-at 1000 --input "$tmp/b-status.tsv" --out "$tmp/b.payload" >/dev/null
if "$server/bin/sasd-monitor-auth-import" --config "$server/etc/sasd-monitor.conf" --input "$tmp/b.payload" --signature "$tmp/b.payload.sig" --now 1050 >/dev/null 2>&1; then echo "rejected host imported" >&2; exit 1; fi

bin/sasd-postinstall --root "$tmp/reinstall" --profile-file "$profile_file" --images "$tmp/images.tsv" --image-version 1.0 --profile web-lab --host client-a.lab.invalid --expires-at 2000000000 --apply >/dev/null
if "$server/bin/sasd-enrollment" --dir "$server/var/enrollment" --action import-request --request "$tmp/reinstall/var/enrollment.request" >/dev/null 2>&1; then echo "reinstallation silently replaced active approval" >&2; exit 1; fi

echo "M7 postinstall/enrollment: PASS (offline identity and approval boundaries)"
