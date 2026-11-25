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
        serviceoff) printf '%s\n' 'profile	package	unit	policy' 'baseline,workstation,server	modemmanager	ModemManager.service	REVIEW_DISABLE' 'laptop	modemmanager	ModemManager.service	KEEP_UNCHANGED' ;;
        syslog) cat <<'SYSLOG'
# Candidate: /etc/rsyslog.d/60-sasd-client.conf
# Dedicated local5 facility; existing distribution routes remain in effect.
if ($syslogfacility-text == "local5") then {
    action(type="omfile" file="/var/log/sasd/client.log"
           fileCreateMode="0640" fileOwner="root" fileGroup="adm" createDirs="off")
}
SYSLOG
            ;;
        logrotate) cat <<'ROTATE'
# Candidate: /etc/logrotate.d/sasd-client
/var/log/sasd/client.log {
    weekly
    rotate 4
    missingok
    notifempty
    compress
    delaycompress
    su root adm
    create 0640 root adm
    sharedscripts
    postrotate
        /usr/lib/rsyslog/rsyslog-rotate
    endscript
}
ROTATE
            ;;
        cronpolicy) printf '%s\n' 'path	policy' '/etc/crontab	KEEP_DISTRIBUTION' '/etc/cron.d	AUDIT_OWNER_MODE' '/etc/cron.daily	AUDIT_OWNER_MODE' '/etc/cron.hourly	AUDIT_OWNER_MODE' '/etc/cron.weekly	AUDIT_OWNER_MODE' '/etc/cron.monthly	AUDIT_OWNER_MODE' '/etc/cron.allow	KEEP_UNCHANGED' '/etc/cron.deny	KEEP_UNCHANGED' ;;
        serviceon) printf '%s\n' 'profile	package	unit	policy' 'baseline,workstation,laptop,server	cron	cron.service	REVIEW_ENABLE' 'workstation,laptop,server	rsyslog	rsyslog.service	REVIEW_ENABLE' 'workstation,laptop,server	sysstat	sysstat.service	REVIEW_ENABLE' 'workstation,laptop	cups	cups.service	REVIEW_ENABLE' 'server	openssh-server	ssh.service	REVIEW_ENABLE' ;;
        logwatchschedule) printf '%s\n' 'profile	package	policy' 'server	logwatch	REUSE_DISTRIBUTION_SCHEDULE' 'baseline,workstation,laptop	logwatch	NOT_SELECTED' ;;
        sshknown) printf '%s\n' 'path	policy' '/etc/ssh/ssh_known_hosts	REVIEW_PINNED_PUBLIC_KEYS' '/etc/ssh/ssh_config	KEEP_UNCHANGED' ;;
        sshpolicy) printf '%s\n' 'path	policy' '/etc/ssh/sshd_config	KEEP_AND_VALIDATE' '/etc/ssh/sshd_config.d	REVIEW_DROP_IN' '/etc/ssh/ssh_config	KEEP_AND_VALIDATE' '/etc/ssh/ssh_config.d	REVIEW_DROP_IN' '/etc/ssh/ssh_host_keys	NEVER_COPY_PRIVATE_KEYS' ;;
        sshx11) printf '%s\n' '# Client candidate; evaluate effective Host/Match precedence first.' 'Host *' '    ForwardX11 no' '    ForwardX11Trusted no' ;;
        aliases) printf '%s\n' 'alias	policy' 'root	EXPLICIT_REVIEWED_DESTINATION' 'other	KEEP_UNCHANGED' ;;
        postfix) printf '%s\n' 'parameter	policy' 'relayhost	EXPLICIT_REVIEWED_RELAY' 'inet_interfaces	LOOPBACK_ONLY' 'mydestination	EMPTY_NULL_CLIENT' 'smtp_tls_security_level	VERIFY_RELAY' 'smtp_sasl_password_maps	NO_CREDENTIALS_IN_REPOSITORY' ;;
        smtp) printf '%s\n' 'smtpd_banner = $myhostname ESMTP' ;;
        sftpcheck) printf '%s\n' 'check	policy' 'sshd-effective	REVIEW_SUBSYSTEM_SFTP' 'host-key	INDEPENDENT_PIN_REQUIRED' 'authentication	OPERATOR_LAB_TEST' 'file-transfer	OPERATOR_LAB_TEST' ;;
        sysstat) printf '%s\n' 'ENABLED="true"' ;;
        logwatch) printf 'MailTo = root@localhost\nMailFrom = logwatch@%s\nDetail = High\nRange = Yesterday\nService = all\n' "$host" ;;
        *) return 2 ;;
    esac
}
