# CFEngine 1 configuration candidate

Deutsch: [Deutsche Fassung](README.de.md)

The 1999 compatibility profile uses **CFEngine 1**, not the later CFEngine 2 configuration described in the 2009 reference book. This folder contains a minimal, independently authored read-only configuration example for checking file metadata without making changes.

`cfagent.conf` is deliberately tiny. It names a harmless disposable lab marker under `/tmp` and requests warning-only action. The candidate follows the historically documented `control`, `actionsequence`, `files`, `any::`, `mode` and `action=warn` shape. It is **not** claimed parsed or executed by CFEngine 1.4.0: no original binary or period operating-system guest was available during this milestone.

The same candidate is kept under `policies/lab-marker.conf`; `examples/role-selection.txt` records the boundary between SASD role labels and native CFEngine classes.

The GNU archive index confirms a `cfengine-1.4.0.tar.gz` archive dated 1997-06-12 and a 1.5.0 archive dated 1999-06-18. Public historical reference material confirms `cfagent`/`cfagent.conf`, `-f`, `-v`, `-n`, `actionsequence`, and the `classes`/`groups` terminology, but this is not native acceptance evidence. See `docs/PROVENANCE.md` for the research boundary.

SASD role classes such as `baseline` and `role_web` are selection labels emitted by `bin/sasd-site-classes`; they are not asserted to be native CFEngine classes until a matching binary is tested.

Do not install the file into /etc/cfengine automatically. Do not run a historical daemon as root or open its control socket to a real network. For unattended drift checks without external dependencies use bin/sasd-config-drift.

Later-profile CFEngine 2 policies should live separately under cfengine/v2, after the exact parser and original commands are verified. Modern CFEngine 3 policy syntax must never be substituted silently.
