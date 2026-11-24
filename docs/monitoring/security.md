# M1 security boundaries

Deutsch: [Deutsche Fassung](security.de.md)

The M1 server is deliberately local and unprivileged. It has no listening socket, remote command path, authentication service, package installer, service registration, or automatic repair mode.

The installer accepts only an approved repository configuration template, rejects system prefixes and symlink components, requires explicit `--apply`, and preserves existing files. Runtime writes use private directories, regular-file checks, exclusive temporary files, and rename. The installer does not provide rollback or privileged deployment.

The importer trusts only an operator-selected local input file. It validates the R2 inventory, check applicability, identifiers, colors, messages, source identifier, and timestamps before writing. This is not secure enrollment. M2 must add host identity validation, operator approval, short-lived credentials, authenticated transport, revocation, and key rotation before accepting remote reports.

HTML output escapes all host, check, color, and message values. Ancestor symlink and hostile concurrent-writer risks remain bounded-lab concerns; do not run the tools as root in a shared or attacker-writable tree.
