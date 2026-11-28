# Nagios candidate integration

Deutsch: [Deutsche Fassung](nagios.de.md)

Nagios is a later product profile, separate from the 1999 NetSaint candidate. The selected research target is the `nagios-1.0a7` release artifact listed by SourceForge with a 13 March 2002 timestamp. Nagios' official history records the 2002 rename from NetSaint; the archive entry is release evidence, not proof that every generated directive is accepted by that binary.

`bin/sasd-config-nagios` reads the shared hosts, roles, checks, services and lifecycle state. Enabled hosts become host, hostgroup and service objects; disabled and removed hosts are omitted. The bounded candidate includes timeperiod, command, contact, contactgroup and servicegroup objects, active/passive checks and notifications. It does not start Nagios, install files or alter a production path.

The command contract is explicit:

    $USER1$/sasd-check-plugin --plugin $USER1$/sasd-check-adapter --check sasd --arg $ARG1$ --arg $HOSTNAME$ --arg $ARG2$

The object arguments are the inventory check and a source token. `$HOSTNAME$`
labels the target. Set `$USER1$` to a trusted plugin directory whose absolute
path uses only literal letters, digits, underscores, hyphens, dots and slash
separators. The generator applies the same restriction to fixture paths and
rejects traversal.

Host objects use `conn!-` for reachability. Service objects retain their
inventory check, for example `http!-` for web service availability and
`disk!-` for filesystem capacity. The `-` token denotes absent measurement
evidence. All three examples return UNKNOWN (exit 3). For a lab demo, pass
`--disk-fixture FILE --fixture-host HOST` together. Only the enabled,
selected host's disk service uses that file. Its output carries
`source=FIXTURE`. The shared adapter can also read a captured local input
with `--offline disk HOST FILE`, which labels the result `source=OFFLINE`.
Check an actual remote filesystem through a separately accepted remote
measurement source. These candidates contain no `LIVE` measurement path.

The shared runner forwards only explicit `--arg` values. The adapter checks
the target, input and observation records before returning exit 0/1/2/3 for
OK/WARNING/CRITICAL/UNKNOWN. For the captured POSIX `df -kP` contract, use
C-locale columns and single-field mount paths. Empty, header-only, malformed
or missing observations give UNKNOWN. The highest severity controls both
exit code and message, with UNKNOWN taking precedence over CRITICAL.
The offline regression resolves macros and runs the generated argument
vector directly.

`--database-config FILE` adds host-bound database services from shared
offline monitoring. See the candidate contract and status projection in
[database monitoring](database.md).

`bin/sasd-status-import-nagios` accepts only SASD's synthetic line format, for example `status web.lab.invalid.http red (1700000000) message`. It applies lifecycle and role checks, rejects duplicates and bounded malformed input, and emits SASD records. It does not parse native `status.dat`, create an authenticated client identity or accept a socket.

Historical evidence reviewed:

- [Nagios history](https://www.nagios.org/about/history/) for the 1999 NetSaint origin and 2002 rename.
- [SourceForge old releases](https://sourceforge.net/projects/nagios/files/OldFiles/) for `nagios-1.0a7.tar.gz` dated 13 March 2002.
- [Nagios object definitions](https://assets.nagios.com/downloads/nagioscore/docs/nagioscore/3/en/objectdefinitions.html) for the long-lived object vocabulary and plugin command model; this is not asserted as exact 1.0a7 parser documentation.

Status: offline candidate, contemporary regression-tested, native Nagios parser acceptance NOT TESTED. No Nagios daemon, listener or notification service is started by SASD.
