#!/bin/sh
# Read-only check of static Debian identity and resolver files.
# A match is not proof of runtime DNS reachability or resolver ownership.
set -eu
LC_ALL=C; export LC_ALL
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
. "$here/lib/policy.sh"
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
[ -d "$root" ] && valid_hostname || usage
expected=$(render_resolver) || usage
short=${host%%.*}; result=0
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
    {sub(/#.*/, ""); if(NF<2) next; if($1=="127.0.1.1") {count++; if(NF==3 && $2==fqdn && $3==short) matched++} if($1=="127.0.0.1") for(i=2;i<=NF;i++) if($i=="localhost") local_ok=1; for(i=2;i<=NF;i++) if(($i==fqdn || $i==short) && $1!="127.0.1.1") conflict=1}
    END{exit(!(count==1 && matched==1 && local_ok && !conflict))}
' "$etc/hosts"; then report hosts OK
else report hosts DRIFT; fi
if ! regular resolv.conf; then report resolver UNKNOWN
elif actual=$(awk '{sub(/#.*/, ""); if($1=="nameserver" || $1=="search" || $1=="domain") {$1=$1; print}}' "$etc/resolv.conf") && [ "$actual" = "$expected" ]; then report resolver OK
else report resolver DRIFT; fi
exit "$result"
