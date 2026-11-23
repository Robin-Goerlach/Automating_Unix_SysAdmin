# Candidate CFEngine 1 laboratory configuration

The year-1999 profile uses **CFEngine 1**, not the later CFEngine 2 configuration demonstrated in the 2009 reference book. This folder is a minimal, independently authored **experimental teaching configuration** for checking file metadata without making changes.

cfagent.conf is deliberately tiny. It names a harmless disposable lab marker under /tmp and requests warning-only action. The example is NOT claimed validated on CFEngine 1.4. Version-specific syntax and action semantics must be checked using a real archived cfagent in a disposable guest before execution.

Do not install the file into /etc/cfengine automatically. Do not run a historical daemon as root or open its control socket to a real network. For unattended drift checks without external dependencies use bin/sasd-config-drift.

Later-profile CFEngine 2 policies should live separately under cfengine/v2, after the exact parser and original commands are verified. Modern CFEngine 3 policy syntax must never be substituted silently.
