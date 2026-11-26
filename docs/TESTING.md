# Testing and compatibility acceptance

Deutsch: [Deutsche Fassung](TESTING.de.md)

## Run the provided suite

    make test

make syntax runs perl -c on the Perl scripts and sh -n on the POSIX shell scripts. tests/smoke.sh exercises synthetic df data, creates a private status spool, checks HTML output, verifies the drift outcome and confirms the MRTG four-line contract. tests/classic.sh additionally exercises passwd UID-0 anomalies, BSD syslog aggregation, NTP source extraction and cron schedule validation.

No network activity or root permissions are needed. `tests/r2-site.sh` validates the four-host role inventory, including malformed inventory rejection, clean and changed role manifests, and the green/yellow status transition. `tests/m1-monitoring.sh` validates configuration, dry-run/apply/repeat installation, preservation, symlink/system-prefix rejection, imports, deterministic stale state, HTML escaping, MRTG template generation, and CRLF configuration input. `tests/m2-enrollment.sh` creates two disposable clients, approves one, rejects the other, verifies SSH signatures, replay and tamper rejection, and checks disable behavior. `examples/monitoring-lab.sh` and `examples/m2-enrollment-lab.sh` are the end-to-end disposable demonstrations.

`tests/m3-native.sh --require` runs the supplied MRTG and RRDtool binaries and checks HTML/PNG/RRD artifacts; without them it reports `SKIPPED`. `tests/m2-ssh-integration.sh --require` runs an actual OpenSSH client/server test when an unprivileged testable `sshd` is available. `tests/m4-backup.sh` and `tests/m4-operations.sh` exercise restore integrity and expiring operator controls.

CI workflow: .github/workflows/test.yml. The workflow runs on a current Ubuntu GitHub Actions image. Optional native tool and SSH gates require their explicit harness commands.

## Exit and state contract

- sasd-config-drift: 0 matches, 1 missing or drifted target, 2 unsafe or missing golden reference; malformed arguments produce a nonzero exit.
- sasd-disk-watch: four tab-separated fields; purple denotes unknown/invalid sample. A warning state is represented in stdout, not the exit status.
- sasd-status-store: validates the complete input before changing status files, serializes cooperating writers with a private spool lock, and exits nonzero on invalid input. A filesystem or process failure during the rename phase can still leave a partially installed batch; full multi-file commit semantics are not claimed.
- sasd-status-board: outputs static HTML; outdated and future-dated statuses become purple.
- sasd-mrtg-counter: four newline-separated values, with first two nonnegative counter values. The program reads a local sample and does not poll an interface.
- sasd-rrd-cycle: optional external program; use a disposable database and make no backward-compatibility claim before testing an actual RRDtool version.

## Missing acceptance work

No archived CFEngine 1, RRDtool 1999 release, MRTG 1999 release, old Perl, legacy Solaris or BSD guest has yet been verified. The CFEngine and MRTG configurations are **candidate examples** and are not production-ready. Future acceptance must record exact binary checksums, OS version, command line, input fixtures, output logs and a restore/cleanup procedure.

## Offline and negative test backlog

- status batch validation before any spool record modification and cooperating-writer serialization;
- status spool directory symlink, hostile ancestor and crash-consistency tests;
- malformed/multibyte/oversized status samples;
- status age simulation and recovery transition;
- config golden/reference ancestor symlink and unreadable-file cases;
- counter wraparound and unknown input behavior;
- trusted host-key handling in a later SSH lab;
- exact historical Perl and cfagent parser acceptance.
- native MRTG parsing and RRDtool lifecycle on selected versions.

M2 additionally requires the local `ssh-keygen` implementation for RSA key generation and `ssh-keygen -Y sign/verify`. `tests/m2-transport.sh` verifies the M2.1 bounded frame and rejection behavior. The suite still does not prove a live SSH channel, host-key installation, account restriction, key rotation, or production transport; those require an isolated `sshd` acceptance run.

M1 optional dependency checks intentionally report `SKIPPED` when MRTG or RRDtool is unavailable. This is not a successful native integration result.

`tests/m5-golden.sh` and `examples/m5-golden-lab.sh` exercise the unprivileged golden-client archive lifecycle, including audit, dry-run/apply boundaries, manifest and checksum verification, excluded identity/runtime data, safe restore, repeated-capture protection and archive/metadata negative cases. The test uses only temporary directories and regular files.

`release/package.sh` accepts an explicit version, Git ref and absolute output directory. With `--test` it checks clean extraction, line endings/executable inputs and the M5–M7 offline tests. `make release-test` creates the same commit-based candidate twice in separate directories and compares the archives; it does not create a tag or release. A package test against `HEAD` deliberately excludes uncommitted working-tree changes.

`tests/m6-netboot.sh` checks the three offline configuration dialects, profile/image relationships, duplicate MAC/IP rejection, secret filtering, TFTP checksum staging, repeated staging and symlink/path failures. `tests/m7-postinstall.sh` checks fresh identities, image-version selection, clone/reinstallation rejection, operator approval/rejection and authenticated status handoff. Neither test starts a network service or claims a native boot.

Checkpoint B's `site-test` target exercises inventory and service selection. The R2 fixture path also covers host-admin, site-config and site-consistency: CRUD writes require `--apply`, disabled hosts are excluded from staged selections, existing staging directories are rejected, and profile or monitoring-inventory mismatches fail closed. This remains offline configuration validation, not native product parsing or deployment.

R2 categories are separate: offline `make test` is required; an optional integration run may use an explicitly selected `cfagent` in a disposable directory; historical acceptance remains open until CFEngine 1 is exercised on a documented period OS with provenance, checksum, command, output and cleanup evidence.

`tests/deployment.sh` exercises controlled multi-product staging, split Big Sister outputs, strict manifest/plan validation, side-effect-free dry-run, stable locking, atomic single-file publication, unchanged repeat, tampered staging rejection, unsafe target rejection and simulated partial-failure rollback with an existing file's content and mode. The integrated laboratory runs the same sequence in its shared lifecycle model. Native daemons and network distribution remain `SKIPPED`.

## Compatibility matrix

The current evidence is deliberately narrow. The WSL development host runs Perl 5.36.0 and a contemporary POSIX shell; `make test` is the CI-style offline evidence for that environment. The source uses post-5.004 Perl syntax in some utilities (including defined-or and substitution-return forms), so Perl 5.004 is not a supported claim. No historical Unix or alternate Perl release is claimed until a named binary and operating-system run is archived.

See [COMPATIBILITY.md](COMPATIBILITY.md) for the evidence table and the exact boundary between observed, CI-verified, integration-verified and historical claims.

## Git checkout line endings

All Unix scripts and fixture text are normalized on checkout via `.gitattributes` with `* text=auto eol=lf`; the root `.editorconfig` also sets LF. The `make syntax` target checks for CR bytes before invoking any script interpreters, so a Windows CRLF checkout produces a clear diagnostic. If a user already checked out with CRLF, they may have to convert affected files after pulling the new attributes. This is a working-tree text normalization, not a semantic code change. See README.md for safe, non-destructive commands.
