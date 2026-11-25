#!/bin/sh
# Exercise the actual transport archive without repository dependencies or DNS traffic.
set -eu
LC_ALL=C; export LC_ALL
[ "$(id -u)" -ne 0 ] || { echo 'Archive execution test SKIPPED: root'; exit 0; }
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
tmp=$(mktemp -d); stage=; report=; fixture=; review=; acceptance=
cleanup(){
    [ -z "$stage" ] || rm -rf -- "$stage"
    [ -z "$report" ] || rm -rf -- "$report"
    [ -z "$fixture" ] || rm -rf -- "$fixture"
    [ -z "$review" ] || rm -rf -- "$review"
    [ -z "$acceptance" ] || rm -rf -- "$acceptance"
    rm -rf -- "$tmp"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM
umask 077
"$here/package.sh" "$tmp/release"
(cd "$tmp/release" && sha256sum -c sasd-debian-client.tar.gz.sha256)
mkdir "$tmp/unpack"
tar --same-permissions -xzf "$tmp/release/sasd-debian-client.tar.gz" -C "$tmp/unpack"
archive=$tmp/unpack/debian-client
# Independent expected file inventory. No local inventory, tests, reports or credentials.
{
    printf '%s\n' install-client.sh dispatch-planned.sh dispatch-fixture.sh plan-client.pl native-preflight.pl native-capabilities.py prepare-native.sh collect-native.sh verify-dns.pl dependencies.tsv verify-baseline.sh apply-baseline.sh recover-baseline.sh lib/transaction.sh lib/task.sh lib/policy.sh lib/sasd-site-inventory checklist.tsv site.example.conf package-policy.tsv inventory-fields.tsv
    awk -F '\t' 'NR>1 {print "tasks/" $1 "_" $3}' "$here/checklist.tsv"
} | sort > "$tmp/expected"
(cd "$archive" && find . -type f -printf '%P\n' | sort) > "$tmp/actual"
cmp "$tmp/expected" "$tmp/actual"
[ -z "$(find "$tmp/unpack" ! -type f ! -type d -print)" ]
while IFS= read -r name; do
    source=$here/$name
    [ "$name" != lib/sasd-site-inventory ] || source=$here/../../bin/sasd-site-inventory
    cmp "$source" "$archive/$name"
    [ "$(stat -c %a "$source")" = "$(stat -c %a "$archive/$name")" ]
done < "$tmp/expected"
printf 'workstation\tsite_workstation\tmodern\troles/workstation.tsv\n' > "$tmp/roles"
printf 'node.lab.invalid\t192.0.2.40\tdebian\tworkstation\t\tbaseline\n' > "$tmp/hosts"
# Run the full candidate path from the extracted archive.
run(){ "$archive/install-client.sh" --hostname=node.lab.invalid --inventory="$tmp/hosts" --roles="$tmp/roles" --site="$archive/site.example.conf" "$@"; }
rc=0; run --stage > "$tmp/stage.out" || rc=$?
[ "$rc" -eq 3 ]
stage=$(sed -n 's/^Candidate directory: //p' "$tmp/stage.out")
case "$stage" in /tmp/sasd-debian-stage.*) ;; *) stage=; exit 1 ;; esac
[ "$(awk 'END{print NR-1}' "$stage/results.tsv")" -eq 116 ]
[ "$(grep -c 'STAGED' "$stage/results.tsv")" -eq 8 ]
grep -q 'WAIT_VERIFIED.*0790_' "$tmp/stage.out"
while IFS="$(printf '\t')" read -r id name status digest; do
    [ "$status" = STAGED ] || continue
    actual=$(sha256sum < "$stage/${id}_$name.candidate")
    [ "${actual%% *}" = "$digest" ]
done < "$stage/results.tsv"
fixture=$(mktemp -d /tmp/sasd-debian-lab.XXXXXXXX)
mkdir "$fixture/etc"
printf 'SASD-DEBIAN-FIXTURE-1\n' > "$fixture/.sasd-fixture"
printf 'old\n' > "$fixture/etc/hostname"
printf '127.0.0.1 localhost\n127.0.1.1 old.lab.invalid old\n::1 localhost\n' > "$fixture/etc/hosts"
printf 'nameserver 192.0.2.99\nsearch old.invalid\n' > "$fixture/etc/resolv.conf"
run --fixture-apply --root="$fixture" > "$tmp/apply.out"
report=$(sed -n 's/^Fixture report: //p' "$tmp/apply.out")
case "$report" in /tmp/sasd-debian-fixture-report.*) ;; *) report=; exit 1 ;; esac
[ "$(cat "$report/status")" = VERIFIED_FIXTURE ]
[ "$(grep -c FIXTURE_VERIFIED "$report/results.tsv")" -eq 3 ]
grep -q '0020.*WAIT_RUNTIME' "$report/results.tsv"
"$archive/verify-baseline.sh" --root="$fixture" --hostname=node.lab.invalid --site="$archive/site.example.conf"
printf 'ID=debian\nVERSION_ID="13"\n' > "$fixture/etc/os-release"
perl "$archive/native-preflight.pl" --root="$fixture" --hostname=node.lab.invalid --address=192.0.2.40 > "$tmp/preflight"
grep -q 'native-apply.*NOT_AUTHORIZED' "$tmp/preflight"
"$archive/prepare-native.sh" --source-root="$fixture" --hostname=node.lab.invalid --inventory="$tmp/hosts" --roles="$tmp/roles" --site="$archive/site.example.conf" > "$tmp/review"
review=$(sed -n 's/^Native review: //p' "$tmp/review")
case "$review" in /tmp/sasd-native-review.*) ;; *) review=; exit 1 ;; esac
[ "$(cat "$review/status")" = PREPARED_NOT_AUTHORIZED ]
[ "$(grep -c UNCHANGED "$review/changes.tsv")" -eq 3 ]
if [ -x /usr/bin/python3 ]; then
    rc=0; /usr/bin/python3 "$archive/native-capabilities.py" --root="$fixture" > "$tmp/capabilities" || rc=$?
    [ "$rc" -eq 3 ]; grep -q 'native-apply.*NOT_AUTHORIZED' "$tmp/capabilities"
else
    echo 'Packaged native capabilities test SKIPPED: python3 unavailable'
fi
rc=0; "$archive/collect-native.sh" --root="$fixture" --hostname=node.lab.invalid --inventory="$tmp/hosts" --roles="$tmp/roles" --site="$archive/site.example.conf" > "$tmp/acceptance" || rc=$?
[ "$rc" -eq 3 ]
acceptance=$(sed -n 's/^Acceptance report: //p' "$tmp/acceptance")
case "$acceptance" in /tmp/sasd-native-acceptance.*) ;; *) acceptance=; exit 1 ;; esac
[ "$(cat "$acceptance/status")" = COLLECTED_NOT_AUTHORIZED ]
grep -q '^G5[[:space:]]NOT_RUN' "$acceptance/gates.tsv"
[ "$(cat "$acceptance/rehearsal/status")" = PREPARED_NOT_AUTHORIZED ]
# Use the unchanged parser test harness against the unpacked executable.
# Copy only into a separate test directory, not the delivered archive.
mkdir "$tmp/dns-test"
cp "$here/test-verify-dns.sh" "$tmp/dns-test/"
cp "$archive/verify-dns.pl" "$tmp/dns-test/"
sh "$tmp/dns-test/test-verify-dns.sh"
rc=0; run --apply > "$tmp/rejected" 2>&1 || rc=$?; [ "$rc" -eq 2 ]
printf 'Archive integration passed: %s exact files, 116 task rows, 8 staged, 3 static fixture checks\n' "$(wc -l < "$tmp/expected")"
