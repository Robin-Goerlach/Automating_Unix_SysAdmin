# NetSaint C4 candidate

NetSaint is a separate historical product profile, not Nagios syntax retroactively applied to 1999. Nagios' official history records Ethan Galstad's 1999 open-source release as NetSaint and the 2002 rename caused by trademark concerns ([history](https://www.nagios.org/about/history/)). A contemporaneous Debian packaging discussion describes GPL network monitoring with host/service checks, plugins and web output ([Debian archive](https://lists.debian.org/debian-devel/1999/11/msg00316.html)). A later FreeBSD archive records a NetSaint 0.0.7 package ([package index](https://archive.freebsd.org/ports/alpha/packages-4.6-release/All/)). These are provenance sources, not native acceptance.

`bin/sasd-config-netsaint` derives a deterministic `hosts.cfg` candidate from the shared inventory. It emits host, hostgroup, service, command, contact, contactgroup and timeperiod objects, excludes disabled and removed hosts, and uses the existing safe output checks. The target is a NetSaint 0.0.7-era profile; the candidate remains `UNVERIFIED` until that binary parses it on a named historical system.

`bin/sasd-check-plugin` executes one explicitly selected executable without a shell, bounds timeout and output, and maps plugin exits 0/1/2/3 to green/yellow/red/purple. Unknown and technical failures are purple; they never become successful checks.

`bin/sasd-status-import-netsaint` accepts only synthetic offline lines of the form `status HOST.CHECK COLOR (EPOCH) MESSAGE`. Shared validation checks identity, role applicability, colors, duplicates and message bounds. It does not parse native `status.dat`, impersonate an authenticated SASD client, open a socket or start NetSaint. Deployment stages the candidate under `netsaint/hosts.cfg`; no production path is touched.

Exact 1999 grammar, arguments, notifications, dependencies and parser compatibility are not claimed. Nagios remains a separate later P4 integration; Ganglia remains P5.
