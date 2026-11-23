# SASD Automating Unix SysAdmin — development roadmap

**Status date:** 2026-11-23. **Initial target environment:** educational late-1990s Unix site, centered on 1999. The 2009 book is a subject reference for later profiles only.

## Gate definitions

- **Implemented:** source exists and tests cover its local behavior.
- **CI verified:** passing contemporary automated test is linked; not proof on period operating systems.
- **Integration verified:** a versioned external CFEngine/MRTG/RRDtool/etc. binary was actually exercised.
- **Historical verified:** a documented reproduction succeeded on the named original Unix/Perl combination.
- **Planned:** no code or acceptance assertion.

The repository must never mislabel a fixture-based test as live network or historical compatibility.

## R0 — Independent baseline (implemented, contemporary CI)

- [x] POSIX shell host facts.
- [x] Perl parser of offline df -kP output and operator thresholds.
- [x] Original SASD four-column status protocol, validated spool writer.
- [x] Static status HTML; stale entries shown as unknown.
- [x] Golden-file drift checker with no modification capability.
- [x] External MRTG-style four-line counter adapter.
- [x] Optional RRDtool create/update wrapper.
- [x] Synthetic fixtures, negative smoke cases and GitHub Actions.
- [x] First offline utilities for passwd UID review, classic syslog, NTP source inventory and user cron schedules.
- [ ] Expand security negative testing (spool/ancestor symlink, truncation, double writers).
- [ ] Prove Perl 5.004 or specify a narrower compatibility promise.

**R0 acceptance:** make test on a clean contemporary Linux host; no network or root privileges; each command documented. Real period Unix acceptance remains open.

## R1 — Pre-1993 Unix utilities (P0/P1)

- passwd/group audit based on local files, avoiding untrusted remote NSS assumptions.
- cron job inventory and conflicts; SysV/BSD startup inventory (read-only).
- syslog summarizer with separate BSD/SysV fixture families.
- file ownership and permission scanner, SUID inventory in report-only mode.
- simple tar/mt and dump/restore inventory and restore verification.
- Bourne shell / awk / sed variants with independent commands, not a single all-in-one framework.

**Acceptance:** fixed POSIX text fixtures, defined error codes, non-privileged launch, explicit per-OS matrix and period claims only after actual tests.

## R2 — Site role management and CFEngine 1 (P1/P2/P3)

- Design simple file-based site inventory and role files.
- Evaluate CFEngine 1.4 historical syntax using a disposable VM and actual binary.
- CFEngine helper: policy inspection, syntax checking, role classification, status reporting; scripts may cooperate with a real cfagent but cannot claim its behavior by emulation.
- Provide read-only, independent SASD config audit for systems without CFEngine.
- Later: guarded staging, backups and explicit opt-in apply with rollback.
- Refuse to manage production /etc, user accounts or services by default.

**Acceptance:** archived CFEngine version, exact operating system, policy dry-run evidence and idempotence test. No unverified auto-remediation.

## R3 — MRTG, SNMP, RRDtool (P2/P3)

- [x] External MRTG four-line data adapter from a local counter fixture.
- [x] RRDtool wrapper for an opt-in file.
- [ ] Run actual MRTG 2 with example config in isolated guest; capture a generated graph.
- [ ] Explain counter wraparound, 32/64-bit SNMP counter limits and 5-minute polling.
- [ ] Implement SNMP v1/v2c adapter **only in a tightly isolated lab** and without embedded community strings.
- [ ] Run RRDtool create/update/fetch/graph lifecycle with deterministic sample timestamps and archive test.
- [ ] Provide separate Nagios/Ganglia-era adapters only in P4/P5.

**Acceptance:** four-line contract check plus archived MRTG and RRDtool exact version runs, verified graph and rate behavior, no production SNMP credentials.

## R4 — Independent centralized monitoring (P2/P3)

- [x] Local status writer, status board, stale evidence.
- [ ] Host and service inventory, scheduled checks, fault/history retention.
- [ ] Acknowledge/maintenance state with expiry and audit logs.
- [ ] Alert throttling and escalation with documented false-positive behavior.
- [ ] A read-only TUI or CGI static-file front end for retro operators.
- [ ] Optional inbound daemon **only after** authentication, bounded protocol, isolation and fail-safe analysis.
- [ ] Separate licensed Big Brother/Xymon interoperability research. Default is no wire compatibility.

**Acceptance:** end-to-end status transitions (green→yellow→red→recovered), stale detection, immutable event evidence, safe HTML encoding and no unauthenticated public network listener.

## R5 — Automated infrastructure provisioning (P4/P5)

- SSH host-key validation and constrained remote command inventory.
- Control of package/bootstrapping manifests and staged configuration files.
- FAI Debian, Kickstart Red Hat, and Solaris JumpStart adapters as independent lab examples.
- Service baseline for NTP, DNS, accounts, NFS and mail routing.
- Apache content and config deployment using rsync with explicit rollback.
- Working CFEngine 2 example set (separate from CFEngine 1 policies).
- Optional Subversion-era staged configuration examples; modern Git remains the actual repo VCS.

**Acceptance:** boot a disposable VM from documented inputs; identify it, stage its config, verify resulting state and restore from an induced failure. No touching production infrastructure.

## R6 — Logs, backups and security (P4/P5)

- Multi-host syslog aggregation with retention and integrity evidence.
- Reproducible application and system restore rehearsals.
- SUID, file permissions, SSH restrictions, sudo, TCP Wrappers and host firewall audits.
- Package/security patch review, no blanket auto-patch or SUID stripping.
- Change and recovery logs in plain-text formats.

**Acceptance:** explicit adversarial fixtures, negative scenarios, partial-failure rollback, and separate read-only vs apply tests.

## R7 — Historical platform verification

Candidate guests in isolation: FreeBSD 3/4, OpenBSD 2/3, Debian 2.x, Red Hat Linux 6.x, Solaris 7/8 and other Unix variants when legally available. Keep platform-specific command output evidence and toolchain versions. Do not list systems as supported merely because their names appear here.

**Exit criterion:** reproducible lab run and saved command output on named exact versions. Modern Linux is a development host, not a historical substitute.

## Source, scope and priority

The priority is R0 hardening, R1 core tools, then R2–R4 in parallel only where their interfaces are independent; R5–R7 follow acceptance. Map topics to the twelve chapters without reproducing the book in docs/BOOK-MAP.md. Add source provenance entries whenever implementation scope is widened.

Open policy decisions: per-module packaging, real legacy OS installation media rights, centrally hosted monitoring threat model, transport security, Big Brother compatibility/legal feasibility, and whether period-specific subtrees should be individually releasable.
