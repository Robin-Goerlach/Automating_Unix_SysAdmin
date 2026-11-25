# Disposable Debian/KVM network-boot laboratory

Deutsch: [Deutsche Anleitung](kvm-lab.de.md)

This is the native M6/M7 acceptance procedure. It requires an authorized Debian KVM/libvirt host, a new disposable guest disk, and an isolated no-forwarding network. WSL alone is not sufficient.

Run the read-only preflight:

```sh
tests/m6-kvm-preflight.sh
tests/m6-kvm-preflight.sh --require
```

The default form reports `SKIPPED` when prerequisites are absent; `--require` exits 2. Neither form creates a network, VM, disk, service, or listener.

## Safety boundary

Use an authorized KVM host. Do not reuse an existing libvirt network, domain, disk, bridge, DHCP service, router, firewall rule, or physical device. Creating the network, VM, disk, and privileged DHCP/TFTP service requires separate authorization; this repository does not automate it.

Record date, OS, libvirt, QEMU, qemu-img, dnsmasq and SSH versions plus preflight output in an evidence directory outside the repository.

## Lab recipe

Use a lab-only RFC 5737 range such as `192.0.2.0/24`, with server `192.0.2.1` and guest `192.0.2.40`; verify it is unused. Create a no-forwarding libvirt network, a new guest, and one new qcow2 disk. Save the network definition, `virsh dumpxml`, and `qemu-img info`. Never attach a physical or existing disk.

Prepare a current Debian netboot tree locally and record exact release, installer build, architecture, source and SHA256 values. Generate and review the SASD fragment, then stage only the verified loader:

```sh
bin/sasd-netboot-config --hosts lab/hosts.tsv --profiles lab/profiles.tsv --images lab/images.tsv --format dnsmasq --out evidence/dnsmasq.conf --apply
bin/sasd-netboot-stage --source lab/boot/pxelinux.0 --tftp-root "$LAB_TFTP_ROOT" --profile debian-current --boot-file pxelinux.0 --sha256 "$PXELINUX_SHA256" --apply
```

For UEFI, use the exact Debian EFI loader instead of substituting `pxelinux.0`. Save `tftp-manifest.tsv`. Generated configuration and checksums are not native evidence until the service and guest are observed.

## Required native evidence

Start only the isolated DHCP/TFTP service and disposable guest. Save service logs, a packet capture, and the guest console. The record must show DHCP assignment to the expected MAC, the selected profile and boot file, successful TFTP transfer, the Debian installer, installation to the new disk, reboot from that disk, and the installed Debian version from console and authenticated SSH.

After installation, run the existing M7 path: `sasd-postinstall`, pending request import, explicit operator approval, `sasd-node-status`, the approved M2.1 fixed-command transfer, `sasd-monitor-auth-import`, and the monitoring report. Confirm a fresh identity and fingerprint. Repeat rejection tests for unapproved, altered, replayed, disabled, stale-image, and active-host reinstallation cases. The installer must not approve itself.

The evidence directory must contain exact versions, network and guest definitions, disk metadata, SASD inputs/outputs, logs, capture, monitoring output, negative-test results, and cleanup transcript. Redact keys and credentials. Remove only the newly created domain, network, TFTP tree, and qcow2 disk after stopping the guest.

This procedure was not executed in the current WSL2 environment. Its native result remains open until this evidence exists.
