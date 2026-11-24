#!/bin/sh
# Prepare an unprivileged SASD node prefix and an offline enrollment request.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
prefix= request= host= role= profile= expires= mode=dry
die(){ echo "install-sasd-client: $*" >&2; exit 2; }
while [ "$#" -gt 0 ]; do
    case "$1" in
        --prefix) [ "$#" -ge 2 ] || die "--prefix needs a value"; prefix=$2; shift 2 ;;
        --request-out) [ "$#" -ge 2 ] || die "--request-out needs a value"; request=$2; shift 2 ;;
        --host) [ "$#" -ge 2 ] || die "--host needs a value"; host=$2; shift 2 ;;
        --role) [ "$#" -ge 2 ] || die "--role needs a value"; role=$2; shift 2 ;;
        --profile) [ "$#" -ge 2 ] || die "--profile needs a value"; profile=$2; shift 2 ;;
        --expires-at) [ "$#" -ge 2 ] || die "--expires-at needs a value"; expires=$2; shift 2 ;;
        --dry-run) mode=dry; shift ;;
        --apply) mode=apply; shift ;;
        --help) echo "usage: install-sasd-client.sh --prefix ABSOLUTE-DIR --role ROLE --profile PROFILE --expires-at EPOCH [--host HOST] [--request-out FILE] [--dry-run|--apply]"; exit 0 ;;
        *) die "unknown argument: $1" ;;
    esac
done
[ -n "$prefix" ] || die "--prefix is required"
case "$prefix" in /*) ;; *) die "prefix must be absolute" ;; esac
case "$prefix" in /|/bin|/sbin|/usr|/usr/*|/etc|/etc/*|/var|/var/*|/home|/home/*|/root|/root/*) die "refusing system prefix: $prefix" ;; esac
case "$prefix" in */../*|*/..|*/./*|*/.) die "unsafe prefix path" ;; esac
[ -n "$role" ] && printf '%s\n' "$role" | grep '^[A-Za-z][A-Za-z0-9_-]*$' >/dev/null || die "invalid role"
[ -n "$profile" ] && printf '%s\n' "$profile" | grep '^[A-Za-z0-9_.:/-]*$' >/dev/null || die "invalid profile"
printf '%s\n' "$expires" | grep '^[0-9][0-9]*$' >/dev/null || die "invalid expiry"
check_ancestors(){ p=$1; while [ "$p" != "/" ] && [ -n "$p" ]; do [ ! -L "$p" ] || die "symlink path component: $p"; n=$(dirname "$p"); [ "$n" != "$p" ] || break; p=$n; done; }
check_ancestors "$prefix"
[ ! -e "$prefix" ] || [ -d "$prefix" ] || die "prefix exists but is not a directory"
os=$(uname -s 2>/dev/null || die "cannot determine operating system")
os_version=$(uname -r 2>/dev/null || die "cannot determine operating-system version")
case "$os" in Linux|FreeBSD|OpenBSD|NetBSD|SunOS|AIX|HP-UX) ;; *) die "unsupported operating system: $os" ;; esac
[ -n "$host" ] || host=$(hostname 2>/dev/null || true)
printf '%s\n' "$host" | grep '^[A-Za-z0-9]\([A-Za-z0-9_.-]*[A-Za-z0-9]\)\{0,1\}$' >/dev/null || die "invalid host"
[ -n "$request" ] || request="$prefix/var/enrollment.request"
case "$request" in /*) ;; *) request="$ROOT/$request" ;; esac
case "$request" in */../*|*/..|*/./*|*/.) die "unsafe request path" ;; esac
check_ancestors "$(dirname "$request")"
[ ! -e "$request" ] || die "request output already exists"
command -v ssh-keygen >/dev/null 2>&1 || die "ssh-keygen is required for the client identity"
echo "os=$os os_version=$os_version host=$host role=$role profile=$profile"
echo "prefix=$prefix"
echo "request=$request"
echo "transport=offline request drop; authenticated SSH submission is not performed"
[ "$mode" = apply ] || { echo "dry-run: no files written"; exit 0; }
umask 077
mkdir -p "$prefix/bin" "$prefix/etc/cron" "$prefix/lib/SASD" "$prefix/var"
for x in sasd-host-facts sasd-disk-watch sasd-node-status sasd-node-send; do
    [ -f "$ROOT/bin/$x" ] && [ ! -L "$ROOT/bin/$x" ] || die "missing approved client source: $x"
    cp "$ROOT/bin/$x" "$prefix/bin/$x"
    chmod 0755 "$prefix/bin/$x"
done
cp "$ROOT/lib/SASD/Monitor.pm" "$prefix/lib/SASD/Monitor.pm"
chmod 0644 "$prefix/lib/SASD/Monitor.pm"
key="$prefix/etc/identity"
[ ! -e "$key" ] && [ ! -L "$key" ] || die "identity already exists"
ssh-keygen -q -t rsa -b 2048 -N '' -f "$key" -C "sasd:$host" >/dev/null
pub=$(sed -n '1p' "$key.pub")
fingerprint=$(ssh-keygen -lf "$key.pub" -E sha256 | awk '{print $2}')
requested=$(date +%s)
printf '%s\n' "$requested" | grep '^[0-9][0-9]*$' >/dev/null || die "cannot determine request time"
printf '%s\n' "$pub" | grep '^[^	][^	]*$' >/dev/null || die "invalid generated public key"
tmp="$request.tmp.$$"
( set -C; printf 'SASD-ENROLL-1\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$host" "$fingerprint" "$os" "$os_version" "$role" "$profile" "$requested" "$expires" "$pub" > "$tmp" ) || die "cannot create request"
mv "$tmp" "$request"
chmod 0600 "$request"
cat > "$prefix/etc/cron/sasd-status.cron" <<EOF
# SASD client cron template; review and install through the local cron policy.
# No cron entry is installed by this script.
# Example status collection command:
# $prefix/bin/sasd-node-status --key $key --sequence NEXT --sent-at EPOCH --input STATUS.tsv --out payload --signature payload.sig
EOF
chmod 0600 "$prefix/etc/cron/sasd-status.cron"
cat > "$prefix/etc/sasd-client.conf" <<EOF
host=$host
os=$os
os_version=$os_version
role=$role
profile=$profile
identity=$key
enrollment_request=$request
EOF
chmod 0600 "$prefix/etc/sasd-client.conf"
echo "client-installation=OK"
echo "fingerprint=$fingerprint"
echo "request=pending-operator-review"
