# SASD 1.0 scope and acceptance

Deutsch: [Deutsche Fassung](RELEASE-1.0.de.md)

Status: release work in progress. No `v1.0.0` tag is authorized until every mandatory gate has evidence.

## Included and verified

- R0, R2, M1 and offline M2 enrollment remain covered by `make test` and disposable laboratories.
- M2.1 client/receiver transport adapter, bounded framing, strict client SSH options, forced-command contract, offline negative tests and installer integration.
- MRTG external-target contract and native MRTG 2.17.10 execution producing HTML and PNG artifacts.
- RRDtool 1.7.2 create/update/fetch/graph lifecycle with deterministic counter samples and a checked PNG artifact.
- Disposable server/client installers with dry-run/apply boundaries and configuration preservation.
- File-based maintenance and acknowledgement records with expiry, operator/reason fields and visible status annotations.
- File-based backup and restore for configuration, inventory, status/history, metrics, reports, operation annotations, public enrollment records and MRTG configuration. Private enrollment key material is excluded.
- English/German operator documentation, negative tests and reproducible offline/native harnesses.

## Included with limitations

- Live SSH transport is implemented but native network acceptance still requires an actual restricted OpenSSH server, reviewed host-key bootstrap and a successful plus rejected transfer. The present environment's extracted OpenSSH 9.2 `sshd` could not bind a test socket (`Operation not permitted`) under the unprivileged WSL sandbox.
- Native M3 evidence uses Debian package versions 2.17.10 and 1.7.2 unpacked under `/tmp`; it is not historical 1999 compatibility evidence and does not poll a production interface.
- Maintenance and acknowledgement annotate canonical M1 state; external email/SMS delivery and a full alert escalation engine are outside this scope.
- Historical Unix, old Perl, CFEngine and product-version compatibility remain unverified unless separately recorded.

## Future extensions

- Restricted live-SSH acceptance on a disposable guest, key rotation and compromised-key recovery rehearsal.
- Optional notification delivery, alert throttling beyond transition deduplication and richer diagnostics.
- Historical MRTG/RRDtool/CFEngine and original Unix guest validation.
- Nagios/Ganglia, SNMP polling, provisioning and automatic remediation.

## Release gate commands

    make test
    examples/monitoring-lab.sh
    examples/m2-enrollment-lab.sh
    tests/m3-native.sh --require
    tests/m4-backup.sh
    tests/m4-operations.sh
    tests/m2-ssh-integration.sh --require

The final gate additionally requires clean extraction testing, checksum manifests, synchronized `main`/`origin/main`, successful Actions for the exact commit and a reviewed annotated tag. Until the SSH command succeeds in a controlled environment, the stable release gate remains open.
