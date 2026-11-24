# Security rules for SASD Unix administration

Deutsch: [Deutsche Fassung](SECURITY.de.md)

Compatibility with older Unix software is not a security exemption. Some optional protocols and daemons are unsafe when exposed to current networks.

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
- M1 monitoring has no listener or automatic enrollment. The installer requires `--apply`, rejects system prefixes and symlink path components, preserves existing files, and writes only to an explicit laboratory prefix. M2.1's SSH receiver is activated only through an administrator-managed OpenSSH forced command.
- M1 import trusts only operator-selected local input. It validates host/check assignment and writes normalized local records; this is not authenticated transport.
- M2 enrollment stores an SSH public-key fingerprint and requires explicit operator approval. A hostname or inventory record alone is never an identity.
- M2 signed payloads use the established `ssh-keygen -Y sign/verify` mechanism. The importer checks the approved key, role/check applicability, expiry, clock window and monotonic sequence before writing M1 state.
- Rejected and disabled records cannot import status. Sequence numbers survive disable/enable to prevent replay.

## Limits of first implementation

Status-store's file replacement is **not audited against hostile concurrent writers** in shared directories. Config-drift rejects symlink final paths but does not guarantee that every ancestor component is symlink-free. The R2 site audit inherits that limitation and adds no apply mode. The HTML writer accepts an operator-selected target file. These tools must not run with elevated privileges or as exposed services until the relevant trust boundaries and race scenarios have been closed.

M1 state/history writes use private runtime directories and bounded retention. M4 backup/restore uses an allowlisted archive and refuses existing destinations. M2.1 does not install or configure SSH; host-key policy, SSH account restrictions, key rotation, compromised-key recovery and clock trust remain required before remote status acceptance in a deployed network.

## External historical software

CFEngine 1 and old MRTG/RRDtool combinations may have known vulnerabilities. Preserve them only inside isolated guests. Licenses and redistribution rights of old software must be checked independently of this project's MIT license.

Report discovered vulnerabilities as private issues or through appropriate security contact mechanisms rather than adding exploitable test infrastructure to a public network.

M5 archives are file-system archives, not bootable images. A live source may be inconsistent; operators must quiesce it or select a consistent snapshot. Host personalization and identity generation are deliberately separate from archive restore. Capture and restore never operate on block devices.
