# SASD site inventory and role assignment

Deutsch: [Deutsche Fassung](README.de.md)

This directory contains a small site inventory for the 1999 compatibility profile. The records use reserved documentation addresses; the tools do not resolve names or contact those addresses.

`hosts.tsv` has six tab-separated fields:

    hostname  address  os-family  role  groups  profile

The first non-empty data section may be preceded by `# SASD-SITE-INVENTORY-1`.
This is the explicit current format version. Existing unmarked files remain
readable as legacy data. Use `bin/sasd-site-migrate --input site/hosts.tsv
--roles site/roles.tsv --dry-run` to inspect a migration, then `--apply` to create a `.pre-versioned`
backup and add the marker. Rows are unchanged; collisions are rejected and a
repeat reports `ALREADY-MIGRATED`.

The address must be an IPv4 value; the example uses `192.0.2.0/24`. `groups` is a comma-separated list (or empty). `profile` is `baseline` or the host's role. `roles.tsv` has four fields:

    role  sasd-class  profile  manifest

The manifest is relative to the selected golden root and is consumed by the read-only audit. A new host is added by appending one validated record and selecting an existing role; a new role requires a role record and a manifest.

`services.tsv` is the versioned service layer: service name, applicable role, existing check name, compatibility profile and description. Validate and resolve it with:

    bin/sasd-site-services --hosts site/hosts.tsv --roles site/roles.tsv \
      --checks site/checks.tsv --services site/services.tsv --host web.lab.invalid

This emits only applicable service selections. It does not probe, start, stop or configure a service. Generators and audits consume explicit files and retain their own safety boundaries.

`bin/sasd-host-admin` is the bounded B-stage inventory editor. `validate`, `list`, `show` and `reconcile` are read-only; `add`, `update`, `enable`, `disable` and `remove` require `--apply`. A sibling state file records the current enabled/disabled/removed projection, while a sibling `*.history.tsv` file retains lifecycle events. `update` preserves a disabled state; `enable` accepts only disabled hosts, `disable` only enabled hosts, and a removed host must be explicitly re-added before it can become active again.

The history fields are `epoch`, `hostname`, `operation`, `from-state`, `to-state` and `reason`. It is operator-owned, mode `0600`, validated before each write and protected by the same lock as the inventory. The file retains logical lifecycle events, but is fully rewritten on each update: it is not append-only and is not tamper-evident audit storage. Inventory, state and history are prepared together and installed with best-effort rollback; a crash between renames can still leave a mixed generation, so recovery requires restoring the last consistent set or operator review.

`bin/sasd-site-config` reads the four inventory layers and emits deterministic `host-services.tsv` and `manifest.tsv` files into a new staging directory. It ignores disabled or removed hosts from the sibling state file. `--check` is read-only; `--apply` only creates the selected staging directory and does not deploy native product configuration.

All five site and product adapters use `SASD::Monitor::read_host_state`. The parser rejects duplicate records, control characters, invalid states, unknown non-removed hosts, direct symlinks and explicitly missing state files. The default sibling state path may be absent and then means that inventory hosts are enabled; `--state` makes absence an error.

`bin/sasd-site-consistency` is a read-only cross-check of the active host/service selection and `site/monitoring.conf`. It verifies that the monitoring model names the same inventory layers, that every active host receives at least one applicable service, and that service profiles match the monitoring profile. It prints the selected host, service, check and profile records followed by a summary; it does not contact hosts or parse a native product configuration.

The existing `bin/sasd-monitor-mrtg` is the first product adapter consuming the lifecycle projection. Pass `--host-state site/hosts.tsv.state` (the default when omitted) to exclude disabled and removed hosts from its reviewable MRTG candidate. The output remains an unverified candidate until the corresponding MRTG version is run.

Run `bin/sasd-site-inventory --check` before using the data. `bin/sasd-site-classes` emits `host`, comma-separated independent SASD classes, role, profile, class and manifest. These class names are selection labels, not a replacement for CFEngine's native class engine.

The audit command delegates file comparison to the existing `bin/sasd-config-drift` program:

    bin/sasd-site-audit --input site/hosts.tsv --roles site/roles.tsv \
      --host web.lab.invalid --root fixtures/site/actual \
      --golden fixtures/site/golden --status

Pipe the final status record to `sasd-status-store` if a local status snapshot is desired. These commands do not copy files, change modes, resolve DNS, or write `/etc`.
