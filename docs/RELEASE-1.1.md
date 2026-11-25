# SASD 1.1 development scope and acceptance

Deutsch: [Deutsche Fassung](RELEASE-1.1.de.md)

Status: development checkpoint completed through M7 offline acceptance. No `v1.1.0` tag is authorized yet.

Acceptance check on 2026-11-25: the available host is WSL2 (`5.15.167.4-microsoft-standard-WSL2`). `virsh`, QEMU, `qemu-img`, `tcpdump`, `sshd`, and a TFTP daemon are unavailable; no libvirt network or disposable VM is present. The read-only preflight therefore reports `SKIPPED`. No native network boot, installation, or postinstall claim is made.

## Included and verified on `main`

- M5 golden-client audit, TAR capture, manifest/checksum catalog and safe file-system restore.
- M6 offline BOOTP, ISC-DHCP and dnsmasq-style configuration generation, profile validation and checksum-controlled TFTP staging.
- Small candidate Solaris JumpStart, Red Hat Kickstart and Debian FAI templates, explicitly unverified against native installers.
- M7 postinstall in an explicit prefix, fresh client identities, image-version selection and pending enrollment request.
- Reuse of existing operator approval, signed status and M1 authenticated import without a second registration service.
- Rejection of duplicate identities, stale image versions, rejected hosts, unsafe profile values and silent reinstallation of active enrollments.
- Offline end-to-end laboratory `examples/sasd-provisioning-lab.sh`.
- Read-only native-lab preflight `tests/m6-kvm-preflight.sh` and the reproducible Debian/KVM procedure in [provisioning/kvm-lab.md](provisioning/kvm-lab.md).

## Included with limitations

- All M5–M7 acceptance currently uses temporary directories and simulated regular files. It does not write block devices or configure a production network.
- Configuration dialects are generated for the named products but native service parsing is not a network-installation acceptance.
- The M5 archive is not bootable; hardware, partition, bootloader and driver compatibility remain operator/platform work.
- Historical JumpStart/Kickstart/FAI compatibility is unverified. Current CI is contemporary Linux only.

## Mandatory gates still open

- A real reproducible network-boot or installation attempt in an explicitly isolated disposable lab, with observed TFTP transfer and reached installation state.
- Native postinstallation after that installation, including new identity, enrollment request, approval and monitoring status.
- Evidence must record exact OS, service versions, boot client, isolated network, commands, logs and cleanup.

Because these gates are open, the project remains on `main` after M7 and no stable `v1.1.0` release is published. The existing `v1.0.0` tag and release remain unchanged.
