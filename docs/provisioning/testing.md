# M5 testing and compatibility

Deutsch: [Deutsche Fassung](testing.de.md)

`tests/m5-golden.sh` creates a synthetic reference tree and exercises audit, dry-run, capture, catalog verification, restore, exclusion of private/temporary data, repeated capture protection, checksum corruption, existing destinations, symlink archives and malformed manifests. `examples/m5-golden-lab.sh` is a shorter operator walkthrough.

The standard test requires no root, network, VM, real disk or production service. It proves a safe file-system archive lifecycle on the current Unix toolchain. It does not prove bootability, partition restoration, hardware compatibility, Solaris JumpStart, Kickstart, FAI or operation on historical Unix releases.

Run:

```sh
make test
examples/m5-golden-lab.sh
```

The exact `tar`, `sha256sum`, OS and architecture used for a deployment acceptance must be recorded separately. A future QEMU/KVM boot test may use only a test-generated image and must remain isolated from production networks and disks.
