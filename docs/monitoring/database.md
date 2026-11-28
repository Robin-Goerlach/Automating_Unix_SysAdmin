# Offline database health monitoring

Deutsch: [Deutsche Fassung](database.de.md)

SASD Freeware owns `db-probe`, `db-health`, `db-activity` and `db-storage`.
This adapter maps synthetic observations into the shared SASD monitoring
cycle. The test route uses a disposable prefix and needs no database client.

## Instance registry and lab configuration

`site/databases.tsv` contains instance, host, product, expected version,
diagnostic profile and lifecycle. The stable check `db_<instance>` is
derived once from that registry and belongs to its exact host. Instance
names follow the shared identifier grammar and have at most 29 characters.
Validation rejects duplicate instance names and static check collisions,
including case-only differences.
An expected version may name a family or exact version. The diagnostic
profile is descriptive in this slice.

In a disposable monitoring prefix, copy the registry into `etc/databases.tsv`
and add `offline_databases=databases.tsv` to a copy of the installed
configuration. Run `sasd-monitor-config --check` on that configuration.
The checked-in production template leaves this option absent and
`site/checks.tsv` needs no duplicated instance rows.

The default host lifecycle path is the inventory name with a `.state`
suffix. A missing implicit file is an empty projection. If `--state` is
supplied, a missing, unreadable or corrupt file fails closed. A host absent
from a valid sparse projection keeps its inventory default. Disabled and
removed hosts or instances accept no database observation. Their previous
history remains available.

## Observation contract

The first line is `SASD-DB-HEALTH-1`. The following keys occur once each as
`key=value` lines. Values are printable ASCII, 1–240 bytes. Total input is
limited to 4096 bytes. Unknown keys and control bytes are rejected.

| Required keys | Accepted meaning |
| --- | --- |
| `instance`, `host` | Exact registry identities |
| `product`, `version` | `mariadb`, `mysql`, or `postgresql` plus a one- to three-part numeric version |
| `source`, `diagnostic` | `OFFLINE` and `db-health` |
| `observed_at` | UTC epoch seconds, 1–15 digits |
| `scope` | `server` for MySQL/MariaDB, `cluster` for PostgreSQL |
| `connections`, `active`, `uptime` | Nonnegative integers up to 15 digits or `unknown`. Uptime is in seconds |
| `visibility` | `complete`, `partial`, or `unavailable` |

The optional `result` is `ok` (default for existing fixtures) or `failed`.
PostgreSQL active client backends are a subset of the client-backend total.
MySQL/MariaDB report non-atomic server status counters. The adapter does
not impose the PostgreSQL relationship on them. The Freeware contract at the
pinned reference commit documents these definitions and uses PostgreSQL
10+ as a diagnostic prerequisite. [Freeware db-health specification](https://github.com/SASD-Sysadmin/freeware/blob/73074c6be9cef3e351aeaa28881653fdaadc9ff2/docs/commands/db-health.md)

| Product | Accepted synthetic family | Example exercised offline | Native SASD client/server evidence |
| --- | --- | --- | --- |
| MariaDB | 10.11 | 10.11.6 | NOT TESTED |
| MySQL | 8.0 | 8.0.36 | NOT TESTED |
| PostgreSQL | 15 | 15.4 | NOT TESTED |

Other versions remain UNKNOWN even when their format and registry match.
Historical database and platform acceptance remain open.

## Status, import and assessment

Pass both `--warn-active N` and `--crit-active N` for a health assessment.
The limits must satisfy `0 <= warn < crit`. Equality activates the
corresponding threshold. The same connection count can be healthy or
degraded under different policies. Without policy, complete observations
remain UNKNOWN. Stale evidence (default maximum age 900 seconds),
unsupported versions, incomplete visibility, unavailable metrics and failed
diagnostics also yield UNKNOWN for eligible instances.

    host<TAB>check<TAB>color<TAB>message<TAB>observation_epoch

The adapter emits one validated row for an eligible observation. Its message
contains the source marker, diagnostic, instance and explanation in a single
field. Health exits are 0/1/2/3 for green/yellow/red/purple. Untrusted
identities, invalid format, future timestamps and unusable lifecycle evidence
give exit 3 with no row. With no latest observation, the shared cycle reports
UNKNOWN. Older observations cannot replace later observations.

Use `sasd-monitor-import --source offline-db` with the opt-in config and a
file of these rows. Import requires an explicit measurement epoch at or
before `--received-at`, the adapter marker, and the exact host/check
binding. The lab source can only replace its own observations. Repeat
imports of the same row keep its original measurement time. The source
label is provenance supplied by the operator and does not authenticate the
producer. Use only a disposable prefix with isolated status, history,
operations and report paths.

The five-field input preserves the observation epoch for ordering and
freshness. The CLI shows the import time, the cycle records its evaluation
time, and the six-field latest storage retains the epoch of the most recent
accepted observation. There is no separate persisted arrival timestamp or
last-success timestamp across later UNKNOWN observations. Historical
transition rows remain available under the existing retention policy.

`tests/database.sh` verifies both instances on the same host through import,
latest status, cycle, independent transitions, acknowledgement, alert
assessment and the HTML report. The [integrated site lab](../../examples/sasd-integrated-site-lab.sh)
also imports both fixtures and renders their observation times. Native
SQL clients, servers, TLS and transport require separate acceptance.

## Historical product candidates

Pass `--database-config FILE` to either classic configuration generator
to add one service per eligible instance. The macro argument vector
points to the opt-in SASD lab configuration and calls the shared adapter.
It reads the canonical cycle verdict and checks freshness again at plugin
time. Missing state, stale observations, source mismatch and targets
removed since generation return UNKNOWN. The candidate pairs the host with
the exact `db_<instance>` service and preserves exits 0/1/2/3.

    bin/sasd-db-status-export --config FILE --product bigbrother
    bin/sasd-db-status-export --config FILE --product bigsister

These are synthetic review records for the two existing SASD interfaces.
Big Brother emits `host.check color (epoch) message`. Big Sister requires
the leading `status` token. The epoch is present when the canonical row
has a valid observation time. Both retain distinct checks and UNKNOWN.
The exports neither publish to the daemons nor change the canonical state.

## Numeric candidates

For a validated snapshot, pass `--instance ID` and
`--format mrtg` or `--format rrd` instead of health options. This selects
one instance and evaluates evidence quality independently of health
thresholds.

| Metric | Unit | Time-series type |
| --- | --- | --- |
| `connections` | Connections or client backends | Gauge |
| `active` | Active sessions or client backends | Gauge |
| `uptime` | Seconds since server or postmaster start | Gauge |

Uptime is an elapsed duration that may reset on restart. The MRTG external
target emits the two connection/activity gauges, uptime and the
`host/instance` label as four lines. Configure the target with the
`gauge` option, an appropriate limit and no `unknaszero`. Poll on the
normal configured interval with no synthetic `--now` override and only
trusted literal paths. On missing or stale evidence the command fails
without gauges. MRTG associates samples with poll time. [MRTG external target reference](https://mrtg.org/mrtg/doc/mrtg-reference.en.html)

RRD mode writes `host<TAB>check<TAB>epoch:connections:active:uptime`.
An eligible unavailable observation emits `U:U:U` and exits 3. Rejected
identity or malformed input emits no sample. Pass only current samples
and, if needed, deliberate UNKNOWN samples in chronological order to
the existing wrapper.

    bin/sasd-rrd-cycle create-database LAB_RRD_DIR HOST db_INSTANCE START_EPOCH
    bin/sasd-rrd-cycle update-database LAB_RRD_DIR SAMPLE.tsv

Use an existing disposable directory with an absolute path and one writer
per instance file. Choose a start epoch strictly before the first
measurement. The wrapper names the file `HOST.db_INSTANCE.rrd` and sends
the observation epoch with an explicit datasource template. The step is
300 seconds and heartbeat 600 seconds. Retention is 24 hours at 5-minute
AVERAGE resolution, and 7 days at 1-hour AVERAGE and MAX resolution.
Consolidation uses an unknown fraction of 0.5. [RRDtool create reference](https://oss.oetiker.ch/rrdtool/doc/rrdcreate.en.html) · [RRDtool update reference](https://oss.oetiker.ch/rrdtool/doc/rrdupdate.en.html)

`tests/database-products.sh` executes generated plugin argument vectors,
parses both synthetic exports, checks the four MRTG target lines, and verifies
RRDtool arguments with a local binary double. The native parsers, notification
delivery, graphs and historical packages still require acceptance.
