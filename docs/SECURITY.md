# Security rules for a historical Unix laboratory

Historical authenticity is not a security exemption. These examples may include protocols and daemons that are unsafe when exposed to current networks.

## Default safe operation

- Use a **disposable guest with host-only/offline networking**, not corporate, residential, cloud or public interfaces.
- Execute as an unprivileged user. Never use sudo for the smoke tests.
- Feed scripts synthetic fixtures first. Avoid copying secrets and real /etc/passwd or /etc/shadow into the repository.
- No host account creation, service restart, firewall change, package installation or network listener is performed by the initial milestone.
- Never ship historical default SNMP community strings, plaintext SSH secrets or weak keys in any network-ready example.
- Validate a guest snapshot and restoration path before enabling legacy SSH, NFS, rsh, telnet or CFEngine daemons.

## Data handling and output

- Reject path traversal, symlink targets, control characters and unsafe status identifiers.
- Site inventory rejects duplicate hostnames, duplicate addresses, invalid IPv4 values, unknown roles and unsafe identifiers before selection.
- Use only an operator-owned private status spool, preferably mode 0700.
- Treat generated static HTML as untrusted until encoding and content checks pass.
- Limit history and discard stale alerts only under a documented retention policy.
- Config-drift has no apply mode. Do not interpret a detected difference as authorization to repair it.

## Limits of first implementation

Status-store's file replacement is **not audited against hostile concurrent writers** in shared directories. Config-drift rejects symlink final paths but does not guarantee that every ancestor component is symlink-free. The R2 site audit inherits that limitation and adds no apply mode. The HTML writer accepts an operator-selected target file. These tools must not run with elevated privileges or as exposed services until the relevant trust boundaries and race scenarios have been closed.

## External historical software

CFEngine 1 and old MRTG/RRDtool combinations may have known vulnerabilities. Preserve them only inside isolated guests. Licenses and redistribution rights of old software must be checked independently of this project's MIT license.

Report discovered vulnerabilities as private issues or through appropriate security contact mechanisms rather than adding exploitable test infrastructure to a public network.
