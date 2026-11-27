# Cross-repository reuse boundary

Deutsch: [Deutsche Fassung](REUSE-ARCHITECTURE.de.md)

This decision keeps generally useful Unix and Linux administration programs in
SASD Freeware and keeps site orchestration in Automating Unix SysAdmin. The
repositories are complementary and must not become a dependency cycle.

## Automating Unix SysAdmin owns

- the shared site inventory, roles and lifecycle;
- historical product profiles and configuration generators;
- monitoring orchestration, state, alert policy and operational views;
- installation, provisioning, staging, apply gates and rollback records; and
- product-specific adapters and offline integration laboratories.

## SASD Freeware owns

- reusable administrative commands and diagnostics;
- resource, filesystem, network, service and platform measurements;
- database diagnostics and product-specific diagnostic backends; and
- stable machine-readable output contracts for independent callers.

The verified reference point used for this boundary is SASD Freeware commit
`73074c6be9cef3e351aeaa28881653fdaadc9ff2`, with Ubuntu and macOS CI jobs
reported successful. That is a reference, not an instruction to install
current `main` or to copy external code. Existing candidates include
`fs-usage`, `fs-report`, account/group audits, process and network reports,
`tcp-check`, DNS/NIS/LDAP/mail probes, syslog summaries, and `db-probe`,
`db-health`, `db-activity` and `db-storage`.

Before adding a generally reusable command here, check the documented
Freeware interface first. Reuse is through a small, versioned CLI contract;
missing features, unsupported versions, incomplete visibility and unsuitable
exit codes remain `UNKNOWN` or `NOT SUPPORTED` until an explicit translation
is accepted. A successful diagnostic process is not automatically a healthy
monitoring result. No change to Freeware is authorized by this document.

Historical profiles in this repository remain independently usable. They do
not acquire a mandatory modern runtime or a mandatory Freeware dependency.
Database integration therefore consumes documented diagnostic output and
maps product/version, instance, host identity, source, observation, metrics,
freshness and monitoring state without treating a host as a unique database
instance.
