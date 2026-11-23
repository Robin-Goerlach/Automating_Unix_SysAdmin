# Testing and historical acceptance

## Run the provided suite

    make test

make syntax runs perl -c on the Perl scripts and sh -n on the POSIX shell scripts. tests/smoke.sh exercises synthetic df data, creates a private status spool, checks HTML output, verifies the drift outcome and confirms the MRTG four-line contract. No network activity or root permissions are needed.

CI workflow: .github/workflows/test.yml. The workflow runs on a current Ubuntu GitHub Actions image. This only establishes the current source's contemporary smoke-test behavior.

## Exit and state contract

- sasd-config-drift: 0 matches, 1 missing or drifted target, 2 unsafe or missing golden reference; malformed arguments produce a nonzero exit.
- sasd-disk-watch: four tab-separated fields; purple denotes unknown/invalid sample. A warning state is represented in stdout, not the exit status.
- sasd-status-store: writes validated records or exits nonzero on invalid input. Files in a partially processed batch may already exist; batch atomicity is not claimed.
- sasd-status-board: outputs static HTML; outdated and future-dated statuses become purple.
- sasd-mrtg-counter: four newline-separated values, with first two nonnegative counter values. The program reads a local sample and does not poll an interface.
- sasd-rrd-cycle: optional external program; use a disposable database and make no backward-compatibility claim before testing an actual RRDtool version.

## Missing acceptance work

No archived CFEngine 1, RRDtool 1999 release, MRTG 1999 release, old Perl, legacy Solaris or BSD guest has yet been verified. The CFEngine and MRTG configurations are **candidate examples** and are not production-ready. Future acceptance must record exact binary checksums, OS version, command line, input fixtures, output logs and a restore/cleanup procedure.

## Offline and negative test backlog

- batch validation before any spool record modification;
- status spool directory symlink and race tests;
- malformed/multibyte/oversized status samples;
- status age simulation and recovery transition;
- config golden/reference ancestor symlink and unreadable-file cases;
- counter wraparound and unknown input behavior;
- trusted host-key handling in a later SSH lab;
- exact historical Perl and cfagent parser acceptance.
