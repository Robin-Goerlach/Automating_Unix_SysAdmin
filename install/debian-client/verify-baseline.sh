#!/bin/sh
# Read-only check of static Debian identity and resolver files.
# A match is not proof of runtime DNS reachability or resolver ownership.
set -eu
LC_ALL=C; export LC_ALL
root=; host=; site=
usage(){ echo 'usage: verify-baseline.sh --root=DIR --hostname=FQDN --site=FILE' >&2; exit 2; }
for arg do
    case "$arg" in
        --root=*) root=${arg#*=} ;;
        --hostname=*) host=${arg#*=} ;;
        --site=*) site=${arg#*=} ;;
        *) usage ;;
    esac
done
case "$root" in /*) ;; *) usage ;; esac
[ -d "$root" ] && [ -n "$host" ] && [ -f "$site" ] && [ ! -L "$site" ] || usage
printf '%s\n' "$host" | awk 'NR!=1 {bad=1} {n=split($0,a,"."); if(n<2 || length($0)>253) bad=1; for(i=1;i<=n;i++) if(length(a[i])>63 || a[i]!~/^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$/) bad=1} END{exit(bad || NR!=1)}' || usage
# Compare only well-formed, explicit IPv4 policy values. Never source policy.
expected=$(awk -F= '
    /^#/ || /^$/ {next}
    NF!=2 || $1 !~ /^(dns1|dns2|search)$/ || seen[$1]++ {bad=1; next}
    {v[$1]=$2}
    $1=="search" {n=split($2,a,"."); if(n<1 || length($2)>253) bad=1; for(i=1;i<=n;i++) if(length(a[i])>63 || a[i]!~/^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$/) bad=1}
    $1~/^dns/ {n=split($2,a,"."); if(n!=4) bad=1; for(i=1;i<=n;i++) if(a[i]!~/^(0|[1-9][0-9]*)$/ || a[i]>255) bad=1}
    END{if(bad || !seen["dns1"] || !seen["search"]) exit 1; print "nameserver " v["dns1"]; if(seen["dns2"]) print "nameserver " v["dns2"]; print "search " v["search"]}
' < "$site") || usage
short=${host%%.*}; result=0
# Reject symlink ancestors and non-regular files for a selected fixture.
# Managed resolver symlinks on live Debian are reported UNKNOWN, not followed.
root=$(CDPATH= cd -- "$root" && pwd -P)
etc=${root%/}/etc
regular(){ [ ! -L "$etc" ] && [ -f "$etc/$1" ] && [ ! -L "$etc/$1" ] && [ -r "$etc/$1" ]; }
report(){ printf '%s\t%s\n' "$1" "$2"; case "$2" in UNKNOWN) result=2 ;; DRIFT) [ "$result" -ne 0 ] || result=1 ;; esac; }
if ! regular hostname; then report hostname UNKNOWN
elif [ "$(cat "$etc/hostname")" = "$short" ]; then report hostname OK
else report hostname DRIFT; fi
if ! regular hosts; then report hosts UNKNOWN
elif awk -v fqdn="$host" -v short="$short" '
    {sub(/#.*/, ""); if(NF<2) next; if($1=="127.0.1.1" && $2==fqdn && $3==short) matched++; if($1=="127.0.0.1") for(i=2;i<=NF;i++) if($i=="localhost") local_ok=1; for(i=2;i<=NF;i++) if(($i==fqdn || $i==short) && $1!="127.0.1.1") conflict=1}
    END{exit(!(matched==1 && local_ok && !conflict))}
' "$etc/hosts"; then report hosts OK
else report hosts DRIFT; fi
if ! regular resolv.conf; then report resolver UNKNOWN
elif actual=$(awk '{sub(/#.*/, ""); if($1=="nameserver" || $1=="search" || $1=="domain") {$1=$1; print}}' "$etc/resolv.conf") && [ "$actual" = "$expected" ]; then report resolver OK
else report resolver DRIFT; fi
exit "$result"
