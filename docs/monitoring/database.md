# Database monitoring offline vertical slice

Deutsch: [Deutsche Fassung](database.de.md)

This repository does not reimplement `db-probe`, `db-health`, `db-activity` or
`db-storage`. The reusable diagnostics belong to SASD Freeware. This package
adds only a bounded orchestration adapter for a documented synthetic
`db-health` observation.

`site/databases.tsv` is the instance inventory. Each row names an instance,
host, database product, expected version, profile and lifecycle. A host may
therefore have more than one database instance. Host lifecycle remains owned by
`site/hosts.tsv` and its state file.

`bin/sasd-db-health-adapter` accepts the `SASD-DB-HEALTH-1` key/value fixture
format and emits the common four-column SASD status record. It validates the
instance-to-host mapping, product/version (`MariaDB 10.11`, `MySQL 8.x`, or
`PostgreSQL 10+` in this first slice), enabled lifecycle, complete visibility,
metric values and observation freshness. Active-session thresholds are
explicit options; the adapter does not infer health from connection count
alone. The message includes the non-sensitive technical metrics and the
explicit `source=OFFLINE` label.

The adapter returns green/yellow/red for accepted threshold results and purple
for UNKNOWN conditions such as stale or future observations, missing instances,
disabled hosts, incomplete visibility, version mismatch or malformed metrics.
It never opens a database connection, reads application data, accepts a
password, executes SQL or writes a database.

The fixtures cover healthy, warning, critical, stale, incomplete-visibility,
unknown-instance and version-mismatch observations. `tests/database.sh` and
`examples/sasd-integrated-site-lab.sh` exercise the complete offline path.
These tests prove only the adapter contract; they are not database-server,
client-driver, TLS, authentication or historical-version acceptance.
