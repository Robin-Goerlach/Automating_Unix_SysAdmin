# Controlled configuration deployment

`bin/sasd-config-deploy` is the first bounded deployment control plane for the shared site model. It is an offline, unprivileged tool for an explicitly disposable target prefix. It does not contact hosts, start daemons, install packages, or remove files because an inventory row disappeared.

Preparation reuses the existing generators and stages `site/host-services.tsv`, separate Big Brother and Big Sister candidates, and CFEngine 1/2 candidates. `MANIFEST.tsv` uses version `SASD-DEPLOY-1` and records relative path, SHA-256 and mode. The plan records the manifest checksum and the target checksum (or `MISSING`) for every target file.

    mkdir -m 0700 /tmp/sasd-target
    bin/sasd-config-deploy ... --staging /tmp/sasd-stage --target /tmp/sasd-target --plan /tmp/sasd.plan --prepare
    bin/sasd-config-deploy ... --staging /tmp/sasd-stage --target /tmp/sasd-target --plan /tmp/sasd.plan --dry-run
    bin/sasd-config-deploy ... --staging /tmp/sasd-stage --target /tmp/sasd-target --plan /tmp/sasd.plan --apply

Dry-run validates the manifest and plan without creating a target directory, lock, backup, temporary file or published configuration. Apply requires an existing operator-owned disposable directory below `/tmp` or `/var/tmp`; every relevant ancestor is checked for symlinks, ownership and permissions. The cooperative lock has stable identity and is retained after completion. Apply rechecks all staged checksums and the target snapshot while holding it.

Each changed file is copied into an exclusive temporary file in its destination directory, checked for a complete write, close, mode and SHA-256, then published with `rename`. This is atomic for one file, not a crash-atomic multi-file transaction. Existing files are moved into a private per-run backup before replacement. A controlled failure restores both content and mode; if rollback itself fails, the backup is retained and reported. The test-only `--fail-after N` hook exercises this contract.

The manifest and plan reject unknown or duplicate fields, empty manifests, duplicate target paths, unsafe modes, absolute paths, traversal, symlinks, non-regular files and unexpected additional staging files. The plan is an integrity snapshot, not an authenticity signature: SHA-256 detects changes within the operator's documented trust boundary but cannot prove who approved a manipulated plan. The control plane does not claim crash atomicity or hostile TOCTOU resistance. Big Sister retains combined stdout as a preview; `--display-out FILE --network-out FILE` provides separate staged files after both output paths have been validated.
