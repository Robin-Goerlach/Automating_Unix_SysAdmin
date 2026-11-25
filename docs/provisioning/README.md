# SASD provisioning tools

Deutsch: [Deutsche Fassung](README.de.md)

This directory documents the bounded provisioning work following SASD 1.0. M5 is implemented first: it audits a selected reference tree, captures a file-system TAR archive, records metadata and checksums, catalogs images, and restores only into a new disposable directory.

The tools do not create bootable disks, write block devices, configure DHCP, or install an operating system. M6 network boot and M7 post-install enrollment are separate milestones and must not be inferred from an M5 archive.

## M5 workflow

1. Prepare or quiesce the reference tree. A live archive may be inconsistent; use an operator-selected snapshot when consistency matters.
2. Run `bin/sasd-golden-audit --root DIR --out REPORT --profile PROFILE`. The report distinguishes checks performed from platform-specific checks not performed.
3. Run `bin/sasd-golden-capture --source DIR --repository DIR --image-id ID --version VERSION --profile PROFILE --dry-run`, review the paths, then repeat with `--apply`.
4. Review `manifests/ID.tsv`, `checksums/ID.sha256` and `archives/ID.tar`. Run `bin/sasd-golden-catalog --repository DIR --verify`.
5. Restore to a new laboratory directory with `bin/sasd-golden-restore --repository DIR --image-id ID --dest DIR --dry-run`, then `--apply`.

Capture excludes temporary/runtime trees and private SSH/SASD identity material. Hostname, network settings, bootloader state, hardware drivers, SSH host keys and monitoring identity require post-installation work; an archive is not a golden identity.

See [golden-images.md](golden-images.md), [security.md](security.md) and [testing.md](testing.md). The repeatable offline acceptance is `tests/m5-golden.sh`; the operator walkthrough is `examples/m5-golden-lab.sh`.

M6 offline network-installation preparation is documented in [netboot.md](netboot.md) and [installation-profiles.md](installation-profiles.md). It generates reviewed configuration text and stages explicit boot files, but does not start DHCP/TFTP or claim a native boot.

M7 postinstallation and monitoring handoff is documented in [postinstall.md](postinstall.md). It creates a new client identity and enrollment request in an explicit prefix, then reuses the existing operator approval and authenticated import path.

The native Debian/KVM acceptance recipe and read-only prerequisite check are documented in [kvm-lab.md](kvm-lab.md). It requires an authorized isolated host and does not claim a native result until packet, guest, installation and cleanup evidence exists.

The combined offline demonstration is `examples/sasd-provisioning-lab.sh`. Its output explicitly separates simulated provisioning from real network boot, native OS installation and historical Unix acceptance.


The modern Debian checklist extension is described in [debian-client.md](debian-client.md). Its dispatcher and candidate renderers are independent of M7 enrollment; live apply is not yet implemented.
