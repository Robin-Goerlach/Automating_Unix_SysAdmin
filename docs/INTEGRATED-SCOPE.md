# Integrated infrastructure scope

Deutsch: [Deutsche Fassung](INTEGRATED-SCOPE.de.md)

This document turns the durable development assignment into repository-facing scope. It is a working architecture and acceptance boundary, not a claim that every listed product is implemented.

## Direction and profiles

SASD remains an independently authored collection of small Unix administration tools. The 1999 profile favors POSIX shell, Perl, awk, sed, cron and text files. Separate later profiles may cover CFEngine 2, Nagios, Ganglia, FAI/Kickstart/JumpStart and related 2002–2009 practice. CFEngine 1 and CFEngine 2, NetSaint and Nagios, and Big Brother and Big Sister remain distinct integrations. No book source, proprietary product code or invented historical provenance is part of this repository.

The long-term system connects a versioned host/service inventory to independent configuration generators, monitoring adapters, provisioning preparation and static operational reports. It does not require a central daemon or database. Secrets stay outside the ordinary inventory.

## Current checkpoint boundary

Checkpoint A covers reproducible offline hardening, test and release checks, and a compatibility matrix. Current evidence includes bounded archive handling, netboot/postinstall negative tests, status-store batch validation and cooperative-writer locking. Crash-atomic multi-file commits, hostile TOCTOU resistance and native product or historical-Unix acceptance remain open.

Checkpoint B is being built incrementally:

- `site/hosts.tsv`, `site/roles.tsv`, `site/checks.tsv` and `site/services.tsv` are the shared text model. `hosts.tsv` accepts the explicit `# SASD-SITE-INVENTORY-1` marker while unmarked legacy files remain readable; `bin/sasd-site-migrate` performs an offline, backed-up, repeatable migration.
- `bin/sasd-site-inventory`, `bin/sasd-site-services`, `bin/sasd-site-classes` and `bin/sasd-site-audit` validate and select existing work.
- `bin/sasd-host-admin` provides explicit, local inventory CRUD with `--apply` as the write gate.
- `bin/sasd-site-config` produces a deterministic staged host/service selection and a consistency report; it does not claim to generate native CFEngine, MRTG, Nagios, DHCP or TFTP syntax.
- `bin/sasd-monitor-mrtg` is the first existing product adapter to consume the same host lifecycle projection and omit disabled or removed hosts from its candidate output.
- `bin/sasd-config-bigbrother` is an independent, review-only host/service candidate generator using the same inventory and lifecycle projection. It is not native Big Brother acceptance evidence.

The next B increments are additional product-specific generators, a controlled deploy/apply boundary and a fuller offline end-to-end lab. Host lifecycle event retention is now implemented by `sasd-host-admin`. A disabled or removed host must not cause historical monitoring data to be deleted. Current host state is represented separately from the active inventory.

## Security and operational boundaries

All administrative writes require an explicit operation and, where applicable, `--apply`. Inputs are newline-oriented TSV with bounded identifiers, duplicate detection, path validation and no shell evaluation. Staging destinations must be disposable and are replaced only after validation. No command starts a service, opens a listener, changes a block device, installs a package, approves enrollment or contacts an inventory address.

Database monitoring is intended for read-only technical health checks of real enterprise database platforms, never for copying HR, CRM, sales or customer data. Adapters must use least privilege, bounded time/output, parameter binding and version-specific queries. Unsupported checks are UNKNOWN/NOT SUPPORTED, not success. Firebase is a later cloud/NoSQL adapter; Firebird is a separate database product; PL/SQL is Oracle-specific.

## Planned integration layers

The assignment covers CFEngine 1/2, MRTG, RRDtool, Big Brother, Big Sister, NetSaint, Nagios, Ganglia, SASD monitoring, BOOTP/DHCP, TFTP, golden-client/image workflows, automated installation, database probes and a later read-only administration console. Each integration needs its own version matrix, fixture and negative tests. A candidate configuration is not native compatibility evidence. Modern CI proves only the named modern runner.

The infrastructure installer and client installer will first support dry-run and disposable-prefix staging. The installation server will orchestrate established DHCP/TFTP/install tools rather than implement a new network daemon. Network boot, historical operating systems and production changes require separately documented native acceptance.

## Acceptance vocabulary and releases

Use `PASS`, `FAIL`, `SKIPPED`, `NOT TESTED`, `BLOCKED` and `PENDING` precisely. V1.0.0 remains unchanged. V1.1.0 is not released before the documented native M6/M7 gates. Later integrated work must not be silently mixed into that release. Every meaningful English documentation change has a German `.de.md` companion.

The authoritative durable assignment is `../logs/MASTER-ASSIGNMENT.md`; it is read at the beginning of every development session and is never replaced by this summary or by `LAST-SESSION.md`.
