#!/bin/sh
# Modern Debian candidate generation only. Never source site data.
. "$here/lib/policy.sh"
task_main() {
    kind=$1; handler=$2; shift 2
    mode=dry; host=; site=
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --dryrun|--dry-run) mode=dry ;;
            --render) mode=render ;;
            --hostname=*) host=${1#*=} ;;
            --site=*) site=${1#*=} ;;
            *) echo 'Invalid task argument' >&2; return 2 ;;
        esac
        shift
    done
    LC_ALL=C; export LC_ALL
    valid_hostname || { echo 'Invalid hostname' >&2; return 2; }
    case "$kind" in
        manual) echo 'Operator action required'; return 21 ;;
        central) echo 'Central inventory or administrator-owned service'; return 22 ;;
        review) echo 'Policy, hardware or safety review required'; return 23 ;;
        deferred) echo 'Implementation or site input pending'; return 20 ;;
        render) ;;
        *) return 2 ;;
    esac
    if [ "$handler" = resolver ]; then
        [ -n "$site" ] && [ -f "$site" ] && [ ! -L "$site" ] || { echo 'Site DNS file required'; return 20; }
        resolver_output=$(render_resolver) || { echo 'Invalid site DNS data' >&2; return 2; }
    fi
    [ "$mode" = render ] || { echo 'Candidate can be rendered; no host changes'; return 10; }
    case "$handler" in
        resolver) printf '%s\n' "$resolver_output" ;;
        hostname) printf '%s\n' "${host%%.*}" ;;
        hosts) printf '127.0.0.1 localhost\n127.0.1.1 %s %s\n' "$host" "${host%%.*}" ;;
        packages1) printf '%s\n' vim rsyslog postfix mailutils iptables lm-sensors smartmontools alsa-utils rsync nfs-common cups a2ps fail2ban openssh-server openssh-client openssh-sftp-server bc screen tmux ;;
        packages2) printf '%s\n' vim-doc vim-scripts apt-listchanges needrestart monit rkhunter chkrootkit lynis auditd acct sysstat wget unix2dos snmp logwatch ;;
        banner) printf '%s\n' 'Unauthorized access is prohibited.' ;;
        shell) printf '%s\n' 'umask 027' 'TMOUT=600' 'readonly TMOUT' 'export TMOUT' ;;
        sysstat) printf '%s\n' 'ENABLED="true"' ;;
        logwatch) printf 'MailTo = root@localhost\nMailFrom = logwatch@%s\nDetail = High\nRange = Yesterday\nService = all\n' "$host" ;;
        *) return 2 ;;
    esac
}
