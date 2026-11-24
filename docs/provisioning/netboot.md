# M6 network boot and TFTP staging

Deutsch: [Deutsche Fassung](netboot.de.md)

M6 currently provides offline preparation only. `bin/sasd-netboot-config` validates a controlled host/profile/image set and emits one selected dialect: `isc-dhcp`, `dnsmasq`, or the deliberately separate `bootp` template. It does not start DHCP, send packets, install a service or modify an existing network.

Host input columns are:

```text
hostname  MAC  IPv4  bootserver  tftp-root  boot-file  architecture  install-profile
```

Profile input columns are:

```text
profile  os  architecture  method  source  image-id  role  partition-layout  postinstall  monitoring-profile
```

Image input columns are `image-id`, `version`, `sha256` and `source`. The referenced image is metadata at this stage; M5 archives remain file-system archives and are not silently treated as bootable media. The generator rejects duplicate names, MAC addresses and IPv4 addresses, unknown images/profiles, architecture mismatches, traversal, shell metacharacters and secret-like profile values.

`bin/sasd-netboot-stage` copies an explicitly selected boot file into an explicitly selected laboratory TFTP root. It verifies the source checksum, rejects symlink roots and unsafe paths, protects existing files, and records staged files in `tftp-manifest.tsv`. It never downloads, executes or authenticates a bootloader.

## Dialect and historical boundaries

- `isc-dhcp` is an ISC DHCP-style host declaration; its exact syntax must be checked against the deployed ISC DHCP version.
- `dnsmasq` emits `dhcp-host` and tagged `dhcp-boot` directives; this is a later compact laboratory service, not a 1999 BOOTP claim.
- `bootp` emits a separate classic host declaration. It does not emulate a particular vendor's BOOTP database.
- Solaris JumpStart, Red Hat Kickstart and Debian FAI candidates are under `site/install/adapters/`. They are original small templates and remain unverified until the named OS/installer version is actually run.

The standard test is `tests/m6-netboot.sh`; `examples/m6-netboot-lab.sh` demonstrates configuration and staging only. A real boot requires an isolated server, TFTP service, installation source and disposable client. No such environment was changed or claimed here.
