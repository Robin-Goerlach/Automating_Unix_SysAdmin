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
        rootprofile1) cat <<'PROFILE'
# Optional root interactive profile fragment; preserve existing startup files.
case $- in
    *i*) umask 077; alias ll='ls -l'; alias la='ls -A' ;;
esac
PROFILE
            ;;
        rootprofile2) printf '%s\n' 'path	policy' '/root	REVIEW_PRIVATE_DIRECTORY' '/root/bin	REVIEW_PRIVATE_DIRECTORY' '/root/Documents	REVIEW_PRIVATE_DIRECTORY' '/root/tmp	REVIEW_PRIVATE_DIRECTORY' '/root/mnt	REVIEW_PRIVATE_DIRECTORY' '/root/.profile	KEEP_AND_REVIEW' '/root/.bashrc	KEEP_AND_REVIEW' '/root/.cshrc	KEEP_AND_REVIEW' '/root/.login	KEEP_AND_REVIEW' '/root/.exrc	KEEP_AND_REVIEW' '/root/.vimrc	KEEP_AND_REVIEW' '/root/.curlrc	KEEP_AND_REVIEW' '/root/.ssh/authorized_keys	KEEP_UNCHANGED' 'root-cron	KEEP_AND_REVIEW' ;;
        shell) cat <<'SHELL'
# Optional interactive POSIX-shell fragment; timeout only for Bash.
case $- in
    *i*)
        umask 027
        if [ -n "${BASH_VERSION-}" ] && [ "${TMOUT+x}" != x ]; then
            TMOUT=600
            readonly TMOUT
            export TMOUT
        fi
        ;;
esac
SHELL
            ;;
        cshprofile) cat <<'CSH'
# Optional C-shell fragment; do not replace distribution startup files.
if ( $?prompt ) then
    umask 027
    alias ll 'ls -l'
endif
CSH
            ;;
        compatbsd) printf '%s\n' '# Optional interactive convenience alias, not BSD emulation.' 'case $- in' "    *i*) alias bsdps='ps aux' ;;" 'esac' ;;
        compatlinux) printf '%s\n' 'path	policy' '/srv	KEEP_AND_REVIEW' '/var/log/messages	REVIEW_LOG_ROUTE_NO_HARDLINK' '/etc/sysconfig	NO_GLOBAL_ALIAS' '/etc/HOSTNAME	NO_HARDLINK' ;;
        compatirix) printf '%s\n' 'path	policy' '/etc/openssh	KEEP_EXISTING_NO_NEW_ALIAS' '/etc/ssh	USE_NATIVE_PATH' ;;
        compatsolaris) printf '%s\n' 'path	policy' '/var/home	KEEP_EXISTING_NO_NEW_ALIAS' '/home	USE_NATIVE_PATH' ;;
        compatpager) cat <<'PAGER'
# Optional interactive preference; never replace the more executable.
case $- in
    *i*)
        if [ -z "${PAGER-}" ] && command -v less >/dev/null 2>&1; then
            PAGER=less
            export PAGER
        fi
        ;;
esac
PAGER
            ;;
        compatman) printf '%s\n' 'path	policy' '/usr/man	KEEP_EXISTING_NO_NEW_ALIAS' '/usr/share/man	USE_NATIVE_MANPATH' 'MANPATH	KEEP_DISTRIBUTION_DEFAULT' ;;
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
        fstabformat) printf '%s\n' 'path	policy' '/etc/fstab	PRESERVE_AND_REVIEW' ;;
        fstabsecure) printf '%s\n' 'mountpoint	proposed-options' '/home	nodev,nosuid,noexec' '/tmp	nodev,nosuid,noexec' '/var	nodev,nosuid' '/dev/shm	nodev,nosuid,noexec' ;;
        usbmount) printf '%s\n' 'scope	policy' 'desktop-removable-media	REVIEW_AUTOMOUNT' 'usbfs	DO_NOT_ASSUME_PRESENT' ;;
        nfspoints) printf '%s\n' 'path	policy' '/mnt/sasd	REVIEW_ROOT_OWNED_EMPTY_MOUNTPOINTS' ;;
        nfsshares) printf '%s\n' 'scope	policy' 'nfs	EXPLICIT_READ_ONLY_SHARE_MANIFEST' 'remote-scripts	NEVER_EXECUTE' ;;
        nfsautomount) printf '%s\n' 'mode	policy' 'manual	DEFAULT_NOAUTO' 'on-demand	EXPLICIT_SYSTEMD_AUTOMOUNT_REVIEW' 'autofs	KEEP_EXISTING_MAPS_UNCHANGED' ;;
        localinventory) printf '%s\n' 'field	policy' 'kernel,architecture,logical-cpus,mount-count	LOCAL_OBSERVATION' 'serial,mac,owner	PRIVATE_REVIEW' 'password,passphrase	NEVER_COLLECT' ;;
        cronaccess) printf '%s\n' 'path	policy' '/etc/cron.allow	KEEP_AND_REVIEW' '/etc/cron.deny	KEEP_AND_REVIEW' '/etc/at.allow	KEEP_AND_REVIEW' '/etc/at.deny	KEEP_AND_REVIEW' ;;
        limitsreview) printf '%s\n' 'path	policy' '/etc/security/limits.conf	PRESERVE_AND_REVIEW' '/etc/security/limits.d	WORKLOAD_SPECIFIC_LIMITS_REVIEW' 'systemd-services	REVIEW_UNIT_LIMITS_SEPARATELY' ;;
        pamreview) printf '%s\n' 'path	policy' '/etc/pam.d/common-auth	KEEP_AND_REVIEW' '/etc/pam.d/common-password	KEEP_AND_REVIEW' '/etc/pam.d/common-session	KEEP_AND_REVIEW' 'pam-auth-update	OPERATOR_LAB_REVIEW' ;;
        hashreview) printf '%s\n' 'setting	policy' 'ENCRYPT_METHOD	REVIEW_YESCRYPT_IF_SUPPORTED' 'pam_unix	VERIFY_EFFECTIVE_PASSWORD_POLICY' 'existing-passwords	NO_REHASH_OR_RESET' ;;
        videoreview) printf '%s\n' 'group	policy' 'video	EXPLICIT_LEAST_PRIVILEGE_REVIEW' 'render	EXPLICIT_LEAST_PRIVILEGE_REVIEW' ;;
        sudoreview) printf '%s\n' 'path	policy' '/etc/sudoers	REVIEW_ROOT_OWNED_0440' '/etc/sudoers.d	PRESERVE_AND_REVIEW' 'visudo	OPERATOR_SYNTAX_AND_ACCESS_TEST' 'grants	NO_AUTOMATIC_PRIVILEGE_CHANGE' ;;
        rkhunterpolicy) printf '%s\n' 'scope	policy' 'configuration	KEEP_AND_REVIEW' 'property-database	INDEPENDENT_BASELINE_REVIEW' 'updates	REVIEW_TRUSTED_SOURCE' 'warnings	REVIEW_LOCAL_REPORT' ;;
        clamavpolicy) printf '%s\n' 'scope	policy' 'signature-database	REVIEW_FRESHNESS_AND_SOURCE' 'freshclam	REUSE_DISTRIBUTION_SERVICE' 'scanner	EXPLICIT_SCAN_SCOPE' 'detections	REPORT_ONLY_NO_AUTO_DELETE' ;;
        lynispolicy) printf '%s\n' 'scope	policy' 'profiles	KEEP_AND_REVIEW' 'reports	PRIVATE_OPERATOR_REVIEW' 'remote-script	NEVER_IMPORT_OR_EXECUTE' ;;
        auditdpolicy) printf '%s\n' 'path	policy' '/etc/audit/rules.d	KEEP_AND_REVIEW' '/var/log/audit	REVIEW_CAPACITY_AND_RETENTION' 'rule-load	EXPLICIT_LAB_REVIEW' ;;
        aideschedule) printf '%s\n' 'scope	policy' 'aide	REUSE_DISTRIBUTION_SCHEDULE' 'baseline	APPROVED_INITIALIZATION_REQUIRED' ;;
        rkhunterschedule) printf '%s\n' 'scope	policy' 'rkhunter	REUSE_DISTRIBUTION_SCHEDULE' 'property-update	NEVER_AUTOMATIC' ;;
        chkrootkitschedule) printf '%s\n' 'scope	policy' 'chkrootkit	REUSE_DISTRIBUTION_SCHEDULE' 'findings	OPERATOR_REVIEW' ;;
        auditreport) printf '%s\n' 'scope	policy' 'aureport	REVIEW_PRIVATE_BOUNDED_REPORT' 'retention	EXPLICIT_OPERATOR_POLICY' ;;
        aideinit) printf '%s\n' 'scope	policy' 'initial-database	REVIEW_KNOWN_GOOD_SYSTEM' 'existing-database	KEEP_UNCHANGED' 'approval	INDEPENDENT_OPERATOR_REVIEW' ;;
        aidefinal) printf '%s\n' 'scope	policy' 'database-promotion	EXPLICIT_REVIEW_AFTER_ACCEPTANCE' 'existing-database	KEEP_UNCHANGED' 'drift	REPORT_ONLY' ;;
        smartpolicy) printf '%s\n' 'scope	policy' 'devices	EXPLICIT_DEVICE_REVIEW' 'smartd	KEEP_AND_REVIEW' 'self-test	NO_AUTOMATIC_START' 'reports	REVIEW_CAPTURE' ;;
        sensorpolicy) printf '%s\n' 'scope	policy' 'sensors	REVIEW_CAPTURE' 'sensors-detect	NO_AUTOMATIC_PROBE' 'thresholds	DEVICE_SPECIFIC_LIMITS' ;;
        rngpolicy) printf '%s\n' 'scope	policy' 'kernel-rng	OBSERVE_ONLY' 'rng-tools,haveged	REVIEW_PLATFORM_NEED' 'entropy	NO_GENERIC_HEALTH_THRESHOLD' ;;
        snmppolicy) printf '%s\n' 'scope	policy' 'agent	KEEP_DISABLED_UNLESS_APPROVED' 'transport	REVIEW_SNMPV3_AUTHPRIV' 'credentials	EXTERNAL_PRIVATE_CONFIGURATION' 'access	EXPLICIT_MANAGER_SCOPE' ;;
        monitpolicy) printf '%s\n' 'scope	policy' 'configuration	KEEP_AND_REVIEW' 'checks	OBSERVE_ONLY_INITIAL_POLICY' 'restart	NO_AUTOMATIC_REMEDIATION' 'listener	NO_NEW_LISTENER' ;;
        monitorenroll) printf '%s\n' 'scope	policy' 'big-sister	NO_UNREVIEWED_LEGACY_AGENT' 'sasd-monitoring	REUSE_M2_ENROLLMENT' 'identity	UNIQUE_OPERATOR_APPROVED' 'transport	SEPARATE_AUTHENTICATED_ACCEPTANCE' ;;
        dnsverify) printf '%s\n' 'check	policy' 'direct-dns	USE_VERIFY_DNS_PER_SERVER' 'nss	VERIFY_EXPECTED_ADDRESS' 'result	NO_SYNTHETIC_VERIFICATION' ;;
        essentialhosts) printf '%s\n' 'path	policy' '/etc/hosts	PRESERVE_AND_REVIEW' 'additional-hosts	EXPLICIT_SITE_RECORDS_REQUIRED' 'aliases	REVIEW_CONFLICTS' ;;
        proxypolicy) printf '%s\n' 'scope	policy' 'environment	KEEP_AND_REVIEW' 'apt-proxy	EXPLICIT_PRIVATE_SITE_POLICY' 'credentials	NEVER_STORE_IN_REPOSITORY' 'bypass	REVIEW_LOCAL_SERVICES' ;;
        wlanpolicy) printf '%s\n' 'scope	policy' 'wlan	EXPLICIT_DEVICE_AND_BACKEND_REVIEW' 'credentials	PRIVATE_OPERATOR_INPUT_ONLY' 'network-manager	KEEP_EXISTING_OWNER' ;;
        networkpolicy) printf '%s\n' 'scope	policy' 'address	R2_EXPECTED_IPV4' 'gateway	EXPLICIT_SITE_INPUT' 'backend	ONE_REVIEWED_NETWORK_OWNER' 'ipv6	KEEP_AND_REVIEW' ;;
        networkactivate) printf '%s\n' 'gate	policy' 'console	VERIFIED_OUT_OF_BAND_ACCESS' 'rollback	VERIFIED_LAB_SNAPSHOT' 'activation	EXPLICIT_OPERATOR_LAB_TEST' ;;
        firewallfirst) printf '%s\n' 'scope	policy' 'backend	ONE_REVIEWED_FIREWALL_OWNER' 'inbound	REVIEW_DEFAULT_DENY' 'outbound	REVIEW_REQUIRED_SERVICES' 'management	PRESERVE_VERIFIED_ACCESS' 'ipv6	REVIEW_SEPARATELY' ;;
        firewallverify) printf '%s\n' 'check	policy' 'effective-rules	OPERATOR_LAB_CAPTURE' 'management	POSITIVE_ACCESS_TEST' 'denied-traffic	NEGATIVE_LAB_TEST' 'rollback	REHEARSE_BEFORE_ACTIVATION' ;;
        aptpolicy) printf '%s\n' 'scope	policy' 'sources	REVIEW_RELEASE_PINNED_DEB822' 'archive-keyring	VERIFY_DISTRIBUTION_PACKAGE' 'existing-sources	KEEP_AND_REVIEW' 'third-party	EXPLICIT_REVIEW' ;;
        aptupdate) printf '%s\n' 'scope	policy' 'metadata	EXPLICIT_LAB_REFRESH' 'upgrade	REVIEW_SIMULATION_AND_REBOOT' 'removals	NO_AUTOMATIC_APPROVAL' ;;
        firewallfinal) printf '%s\n' 'scope	policy' 'rules	REVIEW_ROLE_AND_SERVICE_POLICY' 'management	VERIFY_EXISTING_ACCESS' 'activation	LAB_ACCEPTANCE_REQUIRED' 'persist	REVIEW_REBOOT_BEHAVIOR' ;;
        sysstat) printf '%s\n' 'ENABLED="true"' ;;
        logwatch) printf 'MailTo = root@localhost\nMailFrom = logwatch@%s\nDetail = High\nRange = Yesterday\nService = all\n' "$host" ;;
        *) return 2 ;;
    esac
}
