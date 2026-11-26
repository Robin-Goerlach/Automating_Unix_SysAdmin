#!/bin/sh
# Exercise the actual transport archive without repository dependencies or DNS traffic.
set -eu
LC_ALL=C; export LC_ALL
[ "$(id -u)" -ne 0 ] || { echo 'Archive execution test SKIPPED: root'; exit 0; }
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
tmp=$(mktemp -d); stage=; report=; fixture=; review=; acceptance=; lab_report=
cleanup(){
    [ -z "$stage" ] || rm -rf -- "$stage"
    [ -z "$report" ] || rm -rf -- "$report"
    [ -z "$fixture" ] || rm -rf -- "$fixture"
    [ -z "$review" ] || rm -rf -- "$review"
    [ -z "$acceptance" ] || rm -rf -- "$acceptance"
    [ -z "$lab_report" ] || rm -rf -- "$lab_report"
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
    printf '%s\n' install-client.sh dispatch-planned.sh dispatch-fixture.sh plan-client.pl native-preflight.pl native-capabilities.py native-identity.py prepare-native.sh collect-native.sh verify-dns.pl lab-install.py native-install.py plan-packages.py plan-services.py plan-communications.py plan-storage.py plan-shell.py plan-security.py plan-audits.py dependencies.tsv verify-baseline.sh apply-baseline.sh recover-baseline.sh lib/transaction.sh lib/task.sh lib/policy.sh lib/baseline-render.sh lib/sasd-site-inventory checklist.tsv site.example.conf package-policy.tsv package-profiles.tsv inventory-fields.tsv
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
[ "$(grep -c 'STAGED' "$stage/results.tsv")" -eq 30 ]
grep -q 'WAIT_VERIFIED.*0790_' "$tmp/stage.out"
while IFS="$(printf '\t')" read -r id name status digest; do
    [ "$status" = STAGED ] || continue
    actual=$(sha256sum < "$stage/${id}_$name.candidate")
    [ "${actual%% *}" = "$digest" ]
done < "$stage/results.tsv"
fixture=$(mktemp -d /tmp/sasd-debian-lab.XXXXXXXX)
mkdir "$fixture/etc"
printf 'SASD-DEBIAN-FIXTURE-2\n' > "$fixture/.sasd-fixture"
mkdir -p "$fixture/var/lib/sasd/provisioning/transactions"
printf 'old\n' > "$fixture/etc/hostname"
printf '127.0.0.1 localhost\n127.0.1.1 old.lab.invalid old\n::1 localhost\n' > "$fixture/etc/hosts"
printf 'nameserver 192.0.2.99\nsearch old.invalid\n' > "$fixture/etc/resolv.conf"
run --fixture-apply --root="$fixture" > "$tmp/apply.out"
report=$(sed -n 's/^Fixture report: //p' "$tmp/apply.out")
case "$report" in /tmp/sasd-debian-fixture-report.*) ;; *) report=; exit 1 ;; esac
[ "$(cat "$report/status")" = VERIFIED_FIXTURE ]
transaction=$(cat "$report/transaction")
[ "${transaction%/*}" = "$fixture/var/lib/sasd/provisioning/transactions" ]
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
# Run identity comparison from the extracted archive on synthetic local data.
if [ -x /usr/bin/python3 ]; then
    iid=12345678-1234-4234-8234-123456789abc
    printf '%s\n' "$iid" > "$fixture/var/lib/sasd/provisioning/installation-id"
    printf '0123456789abcdef0123456789abcdef\n' > "$fixture/etc/machine-id"
    rc=0; "$archive/native-identity.py" --root="$fixture" --hostname=node.lab.invalid --expected-installation="$iid" > "$tmp/identity" || rc=$?
    [ "$rc" -eq 3 ]; grep -q 'binding.*UNBOUND' "$tmp/identity"
    digest=$(awk -F '\t' '$1=="fingerprint" {print $3}' "$tmp/identity")
    "$archive/native-identity.py" --root="$fixture" --hostname=node.lab.invalid --expected-installation="$iid" --expected-fingerprint="$digest" > "$tmp/identity"
    grep -q 'binding.*MATCH' "$tmp/identity"
    grep -q 'native-apply.*NOT_AUTHORIZED' "$tmp/identity"
    # The packaged and repository release identities must be identical.
    "$archive/lab-install.py" --review --root="$fixture" --hostname=node.lab.invalid --inventory="$tmp/hosts" --roles="$tmp/roles" --site="$archive/site.example.conf" --installation="$iid" --fingerprint="$digest" > "$tmp/reference"
    "$here/lab-install.py" --review --root="$fixture" --hostname=node.lab.invalid --inventory="$tmp/hosts" --roles="$tmp/roles" --site="$archive/site.example.conf" --installation="$iid" --fingerprint="$digest" > "$tmp/source-reference"
    cmp "$tmp/reference" "$tmp/source-reference"
    "$archive/lab-install.py" --apply-fixture --reference="$tmp/reference" --root="$fixture" --hostname=node.lab.invalid --inventory="$tmp/hosts" --roles="$tmp/roles" --site="$archive/site.example.conf" --installation="$iid" --fingerprint="$digest" > "$tmp/lab"
    lab_report=$(sed -n 's/^Fixture report: //p' "$tmp/lab")
    case "$lab_report" in /tmp/sasd-debian-fixture-report.*) ;; *) lab_report=; exit 1 ;; esac
    [ "$(cat "$lab_report/status")" = VERIFIED_FIXTURE ]
    grep -q '^REFERENCE_MATCHED_FIXTURE_ONLY;' "$tmp/lab"
    cp "$here/test-plan-packages.sh" "$archive/test-plan-packages.sh"
    sh "$archive/test-plan-packages.sh"
    rm "$archive/test-plan-packages.sh"
    cp "$here/test-core-services.sh" "$archive/test-core-services.sh"
    sh "$archive/test-core-services.sh"
    rm "$archive/test-core-services.sh"
    cp "$here/test-communications.sh" "$archive/test-communications.sh"
    sh "$archive/test-communications.sh"
    rm "$archive/test-communications.sh"
    cp "$here/test-storage.sh" "$archive/test-storage.sh"
    sh "$archive/test-storage.sh"
    rm "$archive/test-storage.sh"
    cp "$here/test-shell.sh" "$archive/test-shell.sh"
    sh "$archive/test-shell.sh"
    rm "$archive/test-shell.sh"
    cp "$here/test-security.sh" "$archive/test-security.sh"
    sh "$archive/test-security.sh"
    rm "$archive/test-security.sh"
    cp "$here/test-audits.sh" "$archive/test-audits.sh"
    sh "$archive/test-audits.sh"
    rm "$archive/test-audits.sh"
    # Exercise native transaction primitives from packaged code, never the live path.
    cp "$here/test-native-install.sh" "$archive/test-native-install.sh"
    sh "$archive/test-native-install.sh"
    rm "$archive/test-native-install.sh"
else
    echo 'Packaged native identity test SKIPPED: python3 unavailable'
fi
# Use the unchanged parser test harness against the unpacked executable.
# Copy only into a separate test directory, not the delivered archive.
mkdir "$tmp/dns-test"
cp "$here/test-verify-dns.sh" "$tmp/dns-test/"
cp "$archive/verify-dns.pl" "$tmp/dns-test/"
sh "$tmp/dns-test/test-verify-dns.sh"
rc=0; run --apply > "$tmp/rejected" 2>&1 || rc=$?; [ "$rc" -eq 2 ]
printf 'Archive integration passed: %s exact files, 116 task rows, 30 staged, 3 static fixture checks\n' "$(wc -l < "$tmp/expected")"
