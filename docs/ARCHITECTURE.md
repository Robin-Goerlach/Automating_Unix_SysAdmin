# Technical architecture — 1999 profile

Deutsch: [Deutsche Fassung](ARCHITECTURE.de.md)

## System boundary

    POSIX df output / selected local reference files / counter sample
                    |
           independent SASD checkers
           /           |           \
       disk-watch   config-drift   mrtg-counter ----> optional MRTG
           |
     4-column SASD TSV
           |
       status-store ----> spool/*.status ----> status-board ----> static HTML
                                                   (no daemon)
           |
       future alert router (NOT implemented)

    counter stream ----> optional rrd-cycle ----> RRDtool archive

M1 adds a local central state path without adding a daemon:

    R2 inventory + checks.tsv + local observations
                         |
                  monitor-import
                         |
                  latest/ records
                         |
                  monitor-cycle ---> state.tsv + bounded events.tsv
                         |
                  monitor-report ---> static HTML

M2 adds an offline enrollment and authenticated staging path:

    client bootstrap ---> enrollment.request ---> operator approval
          |                                      |
       SSH key + signed payload                 records/ + events.tsv
          |                                      |
          +----------> monitor-auth-import ----> M1 latest/ -> cycle -> report

The R2 site inventory adds a separate, file-based selection path:

    site/hosts.tsv + site/roles.tsv
              |                  \
      site-inventory       site-classes
              |                    |
              +----------> site-audit ---> sasd-config-drift ---> SASD status record

The inventory is an operator-maintained TSV contract. It is not DNS, a CMDB, or a CFEngine parser. Role manifests select reference paths; the existing byte comparator remains responsible for comparison and its exit semantics are preserved.

Complementary independent tools also parse offline passwd snapshots (UID anomalies), traditional BSD syslog (program counts), configured NTP sources and bounded five-field user cron syntax. They do not access credentials, execute jobs, contact time servers or modify accounts.

The layout intentionally avoids a mandatory shared library, database, agent framework or service manager. Unix installations can use only the tools they need. M2 uses the established `ssh-keygen -Y sign/verify` mechanism; M2.1 carries the signed payload through an administrator-configured OpenSSH forced command and does not define a general network protocol.

## Interfaces and status semantics

Checker output:

    host<TAB>check<TAB>color<TAB>message

- host: ASCII letter/digit first, followed by ASCII letter/digit/dot/underscore/hyphen, at most 63 characters.
- check: ASCII letter first, then ASCII letter/digit/underscore/hyphen, at most 32 characters.
- color: green, yellow, red or purple.
- message: single printable line of up to 240 bytes.

The store prepends local epoch seconds and creates per-host/check spool files. A reader treats entries older than the configured age as purple (unknown/stale). This is an original SASD contract; interoperability with BB/Hobbit/Xymon is not claimed.

Disk-watch input is a previously captured **POSIX df -kP** text file or stdin stream; the initial implementation does not invoke live df on its own. Different Unix df implementations must be captured and tested before claiming compatibility.

Config-drift manifest:

    relative_target_path<TAB>relative_golden_path

Both roots are selected by the operator. The first version compares bytes and reports OK / DRIFT / MISSING / UNKNOWN / UNSAFE. It does not change files. Exit codes: 0=no differences, 1=differences, 2=unknown or unsafe. Failure to open or parse is a nonzero error as well.

MRTG adapter input is a four-column TSV with inbound and outbound monotonically increasing counters, uptime and host; its output comprises the four lines required by MRTG's documented external target convention. It **does not** poll a router via SNMP.

RRDtool bridge accepts explicit create or update commands. No archival deletion, automatic file replacement or implicit create-on-update is performed.

## Operational workflow

1. Create an isolated working directory and regular input fixture.
2. Run a read-only collector, examine stdout and status.
3. Write a local status record as an unprivileged process.
4. Generate a static HTML report and inspect it locally.
5. Compare role-specific golden files against chosen lab targets.
6. Optionally feed validated counter files to MRTG and RRDtool.
7. For changes to actual hosts, first create a separate change plan and rollback record (not yet implemented).

## Boundaries and open risks

- Status-store validates a complete batch before modification, serializes cooperating writers with a private lock, and uses exclusive temporary-file creation plus rename. It should not run in a directory writable by untrusted users; crash-atomic multi-file replacement and race-free replacement against an attacker-controlled final path are not formally proven.
- Status-board writes an explicitly chosen file. Do not run it as root or serve the generated HTML on an untrusted webserver without a separate access-control and exposure review.
- Config-drift reads chosen directories and rejects symlink final objects and symlink ancestors in each manifest path. A hostile concurrent rename can still invalidate a check between validation and read: use only trusted lab roots. The R2 site audit inherits this limitation.
- The status format itself has no remote transport or authentication. M2.1 is a separate SSH adapter with explicit host-key trust, forced-command restrictions and serialized receiver staging; it does not add a TCP listener.
- The RRD bridge is useful only if an appropriate RRDtool is installed. A selected target must be tested independently.
- A modern Linux CI job does not prove Solaris, AIX, HP-UX, IRIX, OpenBSD, FreeBSD or older Perl support.

## Site layout plan

Classic deployment may eventually use /usr/local/sasd/bin and /usr/local/sasd/etc, but current code runs directly from the checkout and does not write to /etc or /usr/local. Configuration examples remain under cfengine/, mrtg/, rrd/ and etc/ in the repository.

The current site layout is `site/hosts.tsv`, `site/roles.tsv`, and role manifests below the selected golden root. A host record has hostname, documentation IPv4 address, OS family, one role, comma-separated groups, and profile. All hosts receive the independent `baseline` class; the resolver adds `role_NAME` and `group_NAME`. These names only select SASD work and do not emulate CFEngine's class engine.

Checkpoint B adds an explicit inventory mutation boundary: `sasd-host-admin` edits the active TSV only with `--apply` and records disabled/removed state in a sibling state file. `sasd-site-config` consumes the same model and emits a deterministic staged selection, skipping non-enabled hosts. `sasd-site-consistency` then checks the active selection against the monitoring model and fails on missing services or profile/inventory mismatches. `sasd-config-deploy` adds a bounded manifest/plan/apply path for these review-only candidates in a disposable prefix; it is not a native product validator or network distributor.

M1 uses the same inventory and adds `site/checks.tsv` for check applicability. Its installation template is `site/monitoring.conf`; runtime files are kept under a selected prefix and are separate from source-controlled configuration. `sasd-monitor-import` accepts the existing four-column status contract from local files, while `sasd-monitor-cycle` owns freshness-derived state, operations annotations and bounded transitions. M2 verifies an approved SSH public-key identity, a signed payload, role/check applicability, expiry, clock window and monotonic sequence before handing records to M1. M2.1 provides the optional administrator-configured SSH channel; a live server acceptance remains separate.

M5 adds an independently usable file-system archive path: `golden-audit` examines a selected reference tree; `golden-capture` creates `archives/`, `manifests/` and `checksums/`; `golden-catalog --verify` checks the recorded artifact; and `golden-restore` extracts only into a new disposable directory. The archive is not a raw disk image or bootable installation. Private identities, temporary/runtime trees and pseudo-filesystems are excluded; block devices and mountpoints are outside the interface.
