# M5 golden images

Deutsch: [Deutsche Fassung](golden-images.de.md)

## Audit

`bin/sasd-golden-audit` reads a selected root without modifying it. Its tab-separated report has a header followed by `name<TAB>status<TAB>value` records. `checked` means that the selected fixture path or local host fact was inspected; `not-checked` means that a platform-specific capability needs a separate adapter or an operator decision. The audit does not claim to inspect a physical partition table, hardware dependencies or snapshot consistency.

## Capture repository

The repository has three bounded areas:

```text
images/
  archives/ID.tar
  manifests/ID.tsv
  checksums/ID.sha256
```

The manifest records the UTC capture time, source description, archive format, SHA256, sizes, OS profile, architecture, boot limitation and required post-installation work. The catalog reads manifests; `--verify` checks the referenced archive and checksum record. Large archives belong outside Git.

`sasd-golden-capture` requires an explicit source and repository and requires either `--dry-run` or `--apply`. Existing image names are protected unless the operator supplies `--force`. The normal archive is a file-system TAR, not a raw image and not a bootable installation medium. The capture command uses the local `tar` and `sha256sum` programs and should be run against a quiesced tree or a consistent snapshot.

The default exclusions are temporary/runtime trees, device and pseudo-filesystems, SSH host keys, root/user SSH directories, and SASD identity files. Review the resulting archive and manifest before moving it to an image repository.

## Restore

`sasd-golden-restore` verifies both the manifest checksum and the separate checksum record, checks archive names, rejects path traversal, absolute names, links, hard links, device nodes and FIFOs, and extracts into a private temporary directory before moving it to a destination that did not previously exist. `--dry-run` performs all checks without extraction.

The destination must be a new directory below a trusted laboratory parent. The program intentionally has no `/dev` target, raw-image mode, mount operation, partitioning operation or bootloader installation. Host personalization remains a separate operation.
