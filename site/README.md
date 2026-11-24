# SASD site inventory and role assignment

Deutsch: [Deutsche Fassung](README.de.md)

This directory contains a small site inventory for the 1999 compatibility profile. The records use reserved documentation addresses; the tools do not resolve names or contact those addresses.

`hosts.tsv` has six tab-separated fields:

    hostname  address  os-family  role  groups  profile

The address must be an IPv4 value; the example uses `192.0.2.0/24`. `groups` is a comma-separated list (or empty). `profile` is `baseline` or the host's role. `roles.tsv` has four fields:

    role  sasd-class  profile  manifest

The manifest is relative to the selected golden root and is consumed by the read-only audit. A new host is added by appending one validated record and selecting an existing role; a new role requires a role record and a manifest.

Run `bin/sasd-site-inventory --check` before using the data. `bin/sasd-site-classes` emits `host`, comma-separated independent SASD classes, role, profile, class and manifest. These class names are selection labels, not a replacement for CFEngine's native class engine.

The audit command delegates file comparison to the existing `bin/sasd-config-drift` program:

    bin/sasd-site-audit --input site/hosts.tsv --roles site/roles.tsv \
      --host web.lab.invalid --root fixtures/site/actual \
      --golden fixtures/site/golden --status

Pipe the final status record to `sasd-status-store` if a local status snapshot is desired. These commands do not copy files, change modes, resolve DNS, or write `/etc`.
