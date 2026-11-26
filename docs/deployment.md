# Controlled configuration deployment

`bin/sasd-config-deploy` is the first bounded deployment control plane for the shared site model. It is an offline, unprivileged tool for an explicitly disposable target prefix. It does not contact hosts, start daemons, install packages, or remove files because an inventory row disappeared.

Preparation reuses the existing generators and stages `site/host-services.tsv`, separate Big Brother and Big Sister candidates, and CFEngine 1/2 candidates. `MANIFEST.tsv` uses version `SASD-DEPLOY-1` and records relative path, SHA-256 and mode. The plan records the manifest checksum and the target checksum (or `MISSING`) for every target file.

    bin/sasd-config-deploy ... --staging /tmp/sasd-stage --target /tmp/sasd-target --plan /tmp/sasd.plan --prepare
    bin/sasd-config-deploy ... --staging /tmp/sasd-stage --target /tmp/sasd-target --plan /tmp/sasd.plan --dry-run
    bin/sasd-config-deploy ... --staging /tmp/sasd-stage --target /tmp/sasd-target --plan /tmp/sasd.plan --apply

Dry-run validates the manifest and plan without writing target files, backups or a persistent lock. Apply takes a cooperative target lock, rechecks all staged checksums and the target snapshot, then changes only manifest-listed files. Unchanged files are not rewritten. Existing files are moved into a private backup directory before replacement; the test-only `--fail-after N` hook verifies rollback after a partial operation.

The manifest rejects absolute paths, traversal, symlinks, non-regular files and unexpected additional staging files. The control plane does not claim crash atomicity, hostile TOCTOU resistance, or native Big Brother, Big Sister, CFEngine, MRTG or RRDtool compatibility. Big Sister retains combined stdout as a preview; `--display-out FILE --network-out FILE` provides separate staged files.
