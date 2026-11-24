# M1 security boundaries

Deutsch: [Deutsche Fassung](security.de.md)

The M1/M2 server is deliberately local and unprivileged. It has no listening socket, remote command path, authentication service, package installer, service registration, or automatic repair mode. M2's authenticated path is an offline file exchange verified with an approved SSH public key.

The installer accepts only an approved repository configuration template, rejects system prefixes and symlink components, requires explicit `--apply`, and preserves existing files. Runtime writes use private directories, regular-file checks, exclusive temporary files, and rename. The installer does not provide rollback or privileged deployment.

The importer trusts only an operator-selected local input file. It validates the R2 inventory, check applicability, identifiers, colors, messages, source identifier, and timestamps before writing. M2 adds host identity validation, operator approval, signed payloads, expiry, replay protection and a disable/enable lifecycle for the offline exchange. M2.1 adds a fixed-command SSH adapter, but requires an administrator-managed restricted account, dedicated `known_hosts` and native OpenSSH acceptance. It never changes the SSH daemon configuration.

HTML output escapes all host, check, color, and message values. Ancestor symlink and hostile concurrent-writer risks remain bounded-lab concerns; do not run the tools as root in a shared or attacker-writable tree.
