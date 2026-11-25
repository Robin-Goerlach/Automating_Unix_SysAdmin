# M5-Tests und Kompatibilität

English: [English version](testing.md)

`tests/m5-golden.sh` erzeugt einen synthetischen Referenzbaum und prüft Audit, Dry-Run, Capture, Katalogprüfung, Restore, Ausschluss privater/temporärer Daten, Schutz vor wiederholtem Capture, manipulierte Prüfsummen, vorhandene Ziele, Symlink-Archive und fehlerhafte Manifeste. `examples/m5-golden-lab.sh` ist ein kürzerer Bedienablauf.

Der Standardtest benötigt weder Root noch Netzwerk, VM, echte Platte oder Produktivdienst. Er belegt den sicheren Dateisystem-Archivlebenszyklus auf der aktuellen Unix-Werkzeugkette. Er belegt weder Bootfähigkeit noch Partitions-Restore, Hardwarekompatibilität, Solaris JumpStart, Kickstart, FAI oder Betrieb auf historischen Unix-Versionen.

Ausführen:

```sh
make test
examples/m5-golden-lab.sh
```

Für eine konkrete Installationsabnahme müssen die verwendeten Versionen von `tar`, `sha256sum`, OS und Architektur separat aufgezeichnet werden. Ein späterer QEMU-/KVM-Boottest darf nur ein eigens erzeugtes Testimage verwenden und muss von Produktivnetzen und -datenträgern getrennt bleiben.

Vor einem nativen Versuch `tests/m6-kvm-preflight.sh` ausführen. Das Skript ist lesend und meldet unter WSL oder auf einem unvollständigen Host `SKIPPED`; auf einem freigegebenen KVM/libvirt-Host ist `--require` das Gate. Das vollständige Nachweisverfahren steht in [kvm-lab.de.md](kvm-lab.de.md).
