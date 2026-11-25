# Release packaging

Deutsch: [Deutsche Fassung](RELEASE-PACKAGING.de.md)

`release/package.sh` creates an explicitly versioned, source-only archive from a resolved Git commit. It writes only to the absolute directory supplied with `--out` and refuses existing artifacts. The archive, tree manifest and SHA256 records identify the exact source commit; gzip timestamps are suppressed for reproducible output.

Example:

    release/package.sh --version 1.1.0-dev --ref HEAD --out /tmp/sasd-release --test

`--test` performs clean extraction, LF/executable checks and the M5–M7 offline tests. Run it twice into separate empty directories and compare the archives to verify reproducibility. This is an unreleased local candidate; it does not create a tag or GitHub release. `release/package-1.0.sh` remains the historical V1.0 packaging path and is unchanged.

The package is not a native platform or network-installation acceptance. Missing KVM, DHCP/TFTP, historical Unix or external monitoring tools remain separate `SKIPPED`/`NOT TESTED` gates.
