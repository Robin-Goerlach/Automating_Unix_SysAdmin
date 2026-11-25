#!/bin/sh
# Fixture-only static configuration transaction. No live system operation.
set -eu
LC_ALL=C; export LC_ALL
umask 077
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
. "$here/lib/policy.sh"
root=; host=; site=; mode=dry
fail(){ echo "baseline: $*" >&2; exit 2; }
for arg do
    case "$arg" in
        --root=*) root=${arg#*=} ;;
        --hostname=*) host=${arg#*=} ;;
        --site=*) site=${arg#*=} ;;
        --dryrun|--dry-run) mode=dry ;;
        --apply) mode=apply ;;
        *) fail 'unknown argument' ;;
    esac
done
uid=$(id -u); [ "$uid" -ne 0 ] || fail 'root execution refused'
# Only an explicitly marked, private, direct child of /tmp is supported.
case "$root" in /tmp/sasd-debian-lab.*) ;; *) fail 'not a fixture path' ;; esac
suffix=${root#/tmp/sasd-debian-lab.}
printf '%s\n' "$suffix" | grep -Eq '^[A-Za-z0-9]+$' || fail 'invalid fixture name'
private_dir(){ [ -d "$1" ] && [ ! -L "$1" ] && [ "$(stat -c '%u:%a' -- "$1")" = "$uid:700" ]; }
private_dir "$root" && private_dir "$root/etc" || fail 'fixture directories must be owned and mode 0700'
regular(){ [ -f "$1" ] && [ ! -L "$1" ] && [ "$(stat -c '%u:%h' -- "$1")" = "$uid:1" ] && [ -r "$1" ]; }
regular "$root/.sasd-fixture" && [ "$(cat "$root/.sasd-fixture")" = SASD-DEBIAN-FIXTURE-1 ] || fail 'fixture marker missing'
valid_hostname || fail 'invalid hostname'
expected=$(render_resolver) || fail 'invalid DNS policy'
# Serialize apply runs before reading any target state. Dry-run never writes.
lock=; work=; committed=0; changed=
cleanup(){
    rc=$?; trap - EXIT; trap '' HUP INT TERM
    if [ "$committed" -eq 0 ] && [ -n "$changed" ]; then
        for name in $changed; do
            if ! cp -p -- "$work/original/$name" "$work/restore-$name" || ! mv -fT -- "$work/restore-$name" "$root/etc/$name"; then
                echo "ROLLBACK FAILED: $name; backup=$work/original" >&2; rc=1
            else echo "ROLLED BACK: $name" >&2; fi
        done
    fi
    [ -z "$lock" ] || rmdir -- "$lock" || rc=1
    exit "$rc"
}
if [ "$mode" = apply ]; then
    mkdir -- "$root/.baseline-lock" || fail 'fixture busy'
    lock=$root/.baseline-lock
    trap cleanup EXIT; trap 'exit 1' HUP INT TERM
fi
for name in hostname hosts resolv.conf; do regular "$root/etc/$name" || fail "unsafe or missing $name"; done
old=$(cat "$root/etc/hostname"); short=${host%%.*}
printf '%s\n' "$old" | awk 'NR!=1 || length($0)>63 || $0!~/^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$/ {bad=1} END{exit(bad || NR!=1)}' || fail 'old hostname must be a short name'
# Preserve unrelated entries, IPv6 and comments. Reject ambiguous local mapping.
hosts=$(awk -v old="$old" -v fqdn="$host" -v short="$short" '
    {original=$0; comment=""; if(match($0,/#/)) {comment=substr($0,RSTART); $0=substr($0,1,RSTART-1)}
     if($1=="127.0.0.1") for(i=2;i<=NF;i++) if($i=="localhost") local_ok=1
     if($1=="127.0.1.1") {if(++count>1 || NF<2 || NF>3) bad=1; if(NF==2 && $2!=old && $2!=short) bad=1; if(NF==3 && !(($3==old && index($2,old ".")==1) || ($3==short && $2==fqdn))) bad=1; print "127.0.1.1 " fqdn " " short (comment!="" ? " " comment : ""); next}
     for(i=2;i<=NF;i++) if($i==fqdn || $i==short) bad=1; print original}
    END{if(!local_ok || bad) exit 1; if(!count) print "127.0.1.1 " fqdn " " short}
' "$root/etc/hosts") || fail 'ambiguous hosts mapping or missing localhost'
# Preserve non-policy resolver lines; replace only nameserver/search/domain.
resolver=$(awk '$1!~/^(nameserver|search|domain)$/ {print}' "$root/etc/resolv.conf") || fail 'resolver read failed'
if [ -n "$resolver" ]; then resolver=$(printf '%s\n%s' "$resolver" "$expected"); else resolver=$expected; fi
if [ "$mode" = dry ]; then
    printf 'PLANNED hostname=%s\nPLANNED hosts (preserve unrelated lines)\nPLANNED static resolver (preserve non-policy lines)\n' "$host"
    exit 0
fi
work=$(mktemp -d "$root/baseline.XXXXXXXX")
mkdir "$work/original" "$work/candidate"
for name in hostname hosts resolv.conf; do
    cp -p -- "$root/etc/$name" "$work/original/$name"
    cp -p -- "$root/etc/$name" "$work/candidate/$name"
done
printf '%s\n' "$short" > "$work/candidate/hostname"
printf '%s\n' "$hosts" > "$work/candidate/hosts"
printf '%s\n' "$resolver" > "$work/candidate/resolv.conf"
# Verify the entire candidate before replacing even one file.
mkdir "$work/check"; mv -- "$work/candidate" "$work/check/etc"
"$here/verify-baseline.sh" --root="$work/check" --hostname="$host" --site="$site"
for name in hostname hosts resolv.conf; do
    if cmp -s -- "$work/check/etc/$name" "$root/etc/$name"; then
        printf 'UNCHANGED %s\n' "$name"
    else
        # Record before rename so signal-driven cleanup can restore it.
        changed="$changed $name"
        mv -fT -- "$work/check/etc/$name" "$root/etc/$name"
        printf 'CHANGED %s\n' "$name"
    fi
done
"$here/verify-baseline.sh" --root="$root" --hostname="$host" --site="$site"
committed=1
printf 'FIXTURE ONLY; backup=%s/original\n' "$work"
