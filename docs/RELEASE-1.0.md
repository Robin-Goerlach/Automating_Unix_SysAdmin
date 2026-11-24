# SASD 1.0 scope and acceptance

Deutsch: [Deutsche Fassung](RELEASE-1.0.de.md)

Status: mandatory acceptance evidence is complete on commit `7920cad`. The annotated `v1.0.0` tag and GitHub release are the remaining publication steps.

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

- Live SSH transport is accepted in GitHub Actions run `45392269226` using `/usr/sbin/sshd`, including a successful transfer and rejection with an empty `known_hosts` file. The local unprivileged WSL sandbox still cannot bind the extracted daemon and is not the native-network evidence source.
- Native M3 evidence uses Debian package versions 2.17.10 and 1.7.2 unpacked under `/tmp`; it is not historical 1999 compatibility evidence and does not poll a production interface.
- Maintenance and acknowledgement annotate canonical M1 state; external email/SMS delivery and a full alert escalation engine are outside this scope.
- Historical Unix, old Perl, CFEngine and product-version compatibility remain unverified unless separately recorded.

## Future extensions

- Restricted live-SSH acceptance on a disposable guest, key rotation and compromised-key recovery rehearsal.
- Optional notification delivery, alert throttling beyond transition deduplication and richer diagnostics.
- Historical MRTG/RRDtool/CFEngine and original Unix guest validation.
- Nagios/Ganglia, SNMP polling, provisioning and automatic remediation.

## Acceptance evidence

- GitHub Actions run `45392269226` passed `make test`; its log records `M2.1 SSH integration: PASS sshd=/usr/sbin/sshd` and `documents=52 missing=0 broken_links=0`.
- Native M3 acceptance passed with Debian packages MRTG 2.17.10 and RRDtool 1.7.2 unpacked under `/tmp`, creating and checking HTML, PNG and RRD fetch artifacts.
- M4 backup/restore, maintenance/acknowledgement, both example laboratories and clean release extraction passed locally.
- The release package produced a source archive, manifest and SHA256 checksum manifest without runtime data or private keys.

## Release gate commands

    make test
    examples/monitoring-lab.sh
    examples/m2-enrollment-lab.sh
    tests/m3-native.sh --require
    tests/m4-backup.sh
    tests/m4-operations.sh
    tests/m2-ssh-integration.sh --require

The final gate additionally requires clean extraction testing, checksum manifests, synchronized `main`/`origin/main`, successful Actions for the exact commit and a reviewed annotated tag. These pre-publication checks are complete for `7920cad`; publication must still point exactly to that verified commit.
