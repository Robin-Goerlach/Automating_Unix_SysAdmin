# Nagios candidate integration

Deutsch: [Deutsche Fassung](nagios.de.md)

Nagios is a later product profile, separate from the 1999 NetSaint candidate. The selected research target is the `nagios-1.0a7` release artifact listed by SourceForge with a 13 March 2002 timestamp. Nagios' official history records the 2002 rename from NetSaint; the archive entry is release evidence, not proof that every generated directive is accepted by that binary.

`bin/sasd-config-nagios` reads the shared hosts, roles, checks, services and lifecycle state. Enabled hosts become host, hostgroup and service objects; disabled and removed hosts are omitted. The bounded candidate includes timeperiod, command, contact, contactgroup and servicegroup objects, active/passive checks and notifications. It does not start Nagios, install files or alter a production path.

The command contract is explicit:

    $USER1$/sasd-check-plugin --plugin $USER1$/sasd-check-adapter --check sasd --arg $ARG1$ --arg $HOSTNAME$ --arg $ARG2$

`sasd-check-adapter` currently maps only `disk` to the existing `sasd-disk-watch` program and an explicit controlled input file. Other checks return UNKNOWN/NOT IMPLEMENTED. The target hostname is an identity label and the fixture is an explicit argument; this offline adapter does not pretend to check a remote host or silently check the monitoring server in its place. A real remote check requires a separately accepted agent or native Nagios plugin.

`bin/sasd-status-import-nagios` accepts only SASD's synthetic line format, for example `status web.lab.invalid.http red (1700000000) message`. It applies lifecycle and role checks, rejects duplicates and bounded malformed input, and emits SASD records. It does not parse native `status.dat`, create an authenticated client identity or accept a socket.

Historical evidence reviewed:

- [Nagios history](https://www.nagios.org/about/history/) for the 1999 NetSaint origin and 2002 rename.
- [SourceForge old releases](https://sourceforge.net/projects/nagios/files/OldFiles/) for `nagios-1.0a7.tar.gz` dated 13 March 2002.
- [Nagios object definitions](https://assets.nagios.com/downloads/nagioscore/docs/nagioscore/3/en/objectdefinitions.html) for the long-lived object vocabulary and plugin command model; this is not asserted as exact 1.0a7 parser documentation.

Status: offline candidate, contemporary regression-tested, native Nagios parser acceptance NOT TESTED. No Nagios daemon, listener or notification service is started by SASD.
