# M1 security boundaries

Deutsch: [Deutsche Fassung](security.de.md)

The M1/M2 server is deliberately local and unprivileged. It has no listening socket, remote command path, authentication service, package installer, service registration, or automatic repair mode. M2's authenticated path is an offline file exchange verified with an approved SSH public key.

The installer accepts only an approved repository configuration template, rejects system prefixes and symlink components, requires explicit `--apply`, and preserves existing files. Runtime writes use private directories, regular-file checks, exclusive temporary files, and rename. The legacy status spool additionally validates a complete batch before writing and serializes cooperating writers with a private lock. These measures do not provide crash-atomic multi-file commits or defend an attacker who controls the spool directory. The installer does not provide rollback or privileged deployment.

The importer trusts only an operator-selected local input file. It validates the R2 inventory, check applicability, identifiers, colors, messages, source identifier, and timestamps before writing. The reserved `ssh` source cannot be supplied by the unauthenticated importer. A newer observation cannot be replaced by an older one, and an unauthenticated source cannot replace an authenticated `ssh` observation. Authenticated imports use a stable writer lock and apply the same monotonic checks before updating latest state. M2 adds host identity validation, operator approval, signed payloads, expiry, replay protection and a disable/enable lifecycle for the offline exchange. M2.1 adds a fixed-command SSH adapter, but requires an administrator-managed restricted account, dedicated `known_hosts` and native OpenSSH acceptance. It never changes the SSH daemon configuration.

HTML output escapes all host, check, color, and message values. Ancestor symlink and hostile concurrent-writer attacks outside the cooperating lock protocol remain bounded-lab concerns; do not run the tools as root in a shared or attacker-writable tree.
