# Big Sister candidate integration

Deutsch: [Deutsche Fassung](README.de.md)

Big Sister is treated as a separate historical product. Public documentation describes `adm/bb-display.cfg` as a percent-directive display-collector configuration and `adm/uxmon-net` as a host/check rule file. The generator therefore does not reuse Big Brother `bb-hosts` syntax.

`bin/sasd-config-bigsister` reads the shared hosts, roles, checks, services and lifecycle state and emits a review-only candidate for those two interfaces. Disabled and removed hosts are omitted. `--out` protects inputs and existing-file replacement requires `--force`.

`bin/sasd-status-import-bigsister` accepts bounded synthetic `status host.check color comment` lines and emits SASD's four-column observation format. It validates host/check ownership, colors, message size and duplicate observations. It does not open a socket or claim native protocol compatibility.

The initial profile is marked `2000` because the public change history records Big Sister configuration and status-collector work in 2000. The project site lists 0.99/0.99c3 releases and free software; its license remains external. No Big Sister source, daemon or license text is redistributed here.

References: https://www.bigsister.ch/bigsister.html, https://www.bigsister.ch/pdoc/CONFIG.html, https://www.bigsister.ch/pdoc/CHANGES.html, and https://fossies.org/linux/big-sister/.

Only offline fixture tests exist. A parser run with an exact Big Sister version on historical Unix remains open.
