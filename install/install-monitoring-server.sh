#!/bin/sh
# Install the M1 laboratory server into an explicit, unprivileged prefix.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
prefix= config= mode=dry
die(){ echo "install-monitoring-server: $*" >&2; exit 2; }
while [ "$#" -gt 0 ]; do
    case "$1" in
        --prefix) [ "$#" -ge 2 ] || die "--prefix needs a value"; prefix=$2; shift 2 ;;
        --config) [ "$#" -ge 2 ] || die "--config needs a value"; config=$2; shift 2 ;;
        --dry-run) mode=dry; shift ;;
        --apply) mode=apply; shift ;;
        --help) echo "usage: install-monitoring-server.sh --prefix ABSOLUTE-DIR --config FILE [--dry-run|--apply]"; exit 0 ;;
        *) die "unknown argument: $1" ;;
    esac
done
[ -n "$prefix" ] || die "--prefix is required"
case "$prefix" in /*) ;; *) die "prefix must be absolute" ;; esac
case "$prefix" in /|/bin|/sbin|/usr|/usr/*|/etc|/etc/*|/var|/var/*|/home|/home/*|/root|/root/*) die "refusing system prefix: $prefix" ;; esac
case "$config" in /*) ;; *) config="$ROOT/$config" ;; esac
[ -f "$config" ] && [ ! -L "$config" ] || die "invalid configuration source"
case "$config" in "$ROOT"/site/*) ;; *) die "configuration must be an approved site template" ;; esac
check_ancestors(){ p=$1; while [ "$p" != "/" ] && [ -n "$p" ]; do [ ! -L "$p" ] || die "symlink path component: $p"; n=$(dirname "$p"); [ "$n" != "$p" ] || break; p=$n; done; }
check_ancestors "$prefix"
[ ! -e "$prefix" ] || [ -d "$prefix" ] || die "prefix exists but is not a directory"
"$ROOT/bin/sasd-monitor-config" --config "$config" --check >/dev/null || die "source configuration validation failed"
echo "prefix=$prefix"
echo "config=$config -> $prefix/etc/sasd-monitor.conf"
echo "runtime=$prefix/var/{status,history,metrics,reports}"
echo "optional integrations are never installed or enabled automatically"
[ "$mode" = apply ] || { echo "dry-run: no files written"; exit 0; }
umask 077
for d in bin etc lib lib/SASD var var/status var/status/latest var/history var/metrics var/reports share share/mrtg log; do
    [ ! -L "$prefix/$d" ] || die "installation directory is a symlink: $prefix/$d"
done
mkdir -p "$prefix/bin" "$prefix/etc" "$prefix/lib/SASD" "$prefix/var/status/latest" "$prefix/var/history" "$prefix/var/metrics" "$prefix/var/reports" "$prefix/share/mrtg" "$prefix/log"
copy_once(){ src=$1; dst=$2; mode=$3; [ -f "$src" ] && [ ! -L "$src" ] || die "invalid approved source: $src"; if [ -e "$dst" ] || [ -L "$dst" ]; then [ ! -L "$dst" ] || die "destination is a symlink: $dst"; echo "preserve=$dst"; return; fi; cp "$src" "$dst"; chmod "$mode" "$dst"; echo "install=$dst"; }
for x in sasd-monitor-config sasd-monitor-hosts sasd-monitor-import sasd-monitor-cycle sasd-monitor-report sasd-monitor-mrtg sasd-mrtg-counter sasd-status-store sasd-status-board sasd-site-inventory sasd-site-classes sasd-site-audit; do copy_once "$ROOT/bin/$x" "$prefix/bin/$x" 0755; done
copy_once "$ROOT/lib/SASD/Monitor.pm" "$prefix/lib/SASD/Monitor.pm" 0644
copy_once "$config" "$prefix/etc/sasd-monitor.conf" 0640
for x in hosts.tsv roles.tsv checks.tsv; do copy_once "$ROOT/site/$x" "$prefix/etc/$x" 0640; done
"$prefix/bin/sasd-monitor-config" --config "$prefix/etc/sasd-monitor.conf" --check >/dev/null || die "installed configuration validation failed"
echo "installation=OK"
