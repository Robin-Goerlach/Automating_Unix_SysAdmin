# M5 security boundaries

Deutsch: [Deutsche Fassung](security.de.md)

- Run as an unprivileged user in a disposable directory.
- Select both source and repository explicitly; reject unsafe path components and symlink ancestors.
- Do not point the tools at `/`, an active production tree, a mounted production filesystem or any block device.
- Do not place private keys, enrollment secrets, passwords or production inventory in an image repository.
- Treat a golden archive as untrusted input until its manifest and checksum have been reviewed.
- Restore only to a new directory. Existing destinations, archive links, special files, absolute names and traversal are rejected.
- The archive is not a source of host identity. Generate or provision host-specific SSH and monitoring identities separately.
- A live capture is not guaranteed consistent. Quiesce the source or use a filesystem snapshot before relying on the result.

The tools do not configure a bootloader, partition a disk, mount a filesystem, start a network service or execute post-install scripts. Those operations require separate M6/M7 designs and acceptance tests.
