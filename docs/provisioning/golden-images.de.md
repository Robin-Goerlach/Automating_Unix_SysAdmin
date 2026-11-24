# M5-Golden-Images

English: [English version](golden-images.md)

## Audit

`bin/sasd-golden-audit` liest einen ausgewählten Baum, ohne ihn zu verändern. Der tab-getrennte Bericht enthält nach dem Header Datensätze `Name<TAB>Status<TAB>Wert`. `checked` bedeutet, dass der ausgewählte Fixture-Pfad oder lokale Systemfakt geprüft wurde; `not-checked` bedeutet, dass ein plattformspezifischer Adapter oder eine Betreiberentscheidung nötig ist. Die Prüfung behauptet nicht, physische Partitionstabellen, Hardwareabhängigkeiten oder Snapshot-Konsistenz zu prüfen.

## Capture-Repository

Das Repository hat drei begrenzte Bereiche:

```text
images/
  archives/ID.tar
  manifests/ID.tsv
  checksums/ID.sha256
```

Das Manifest enthält UTC-Erfassungszeit, Quellbeschreibung, Archivformat, SHA256, Größen, OS-Profil, Architektur, Booteinschränkung und erforderliche Postinstallationsarbeiten. Der Katalog liest die Manifeste; `--verify` prüft das referenzierte Archiv und den Checksum-Datensatz. Große Archive gehören nicht in Git.

`sasd-golden-capture` verlangt eine explizite Quelle und ein explizites Repository sowie `--dry-run` oder `--apply`. Vorhandene Image-Namen sind geschützt, außer der Betreiber gibt ausdrücklich `--force` an. Das normale Archiv ist ein Dateisystem-TAR, kein Raw-Image und kein bootfähiges Installationsmedium. Der Befehl verwendet die lokalen Programme `tar` und `sha256sum` und sollte gegen einen angehaltenen Baum oder einen konsistenten Snapshot laufen.

Standardmäßig ausgeschlossen sind temporäre Laufzeitbäume, Geräte- und Pseudodateisysteme, SSH-Hostschlüssel, SSH-Verzeichnisse von root/Benutzern und SASD-Identitätsdateien. Das fertige Archiv und Manifest sind vor einer Ablage im Image-Repository zu prüfen.

## Restore

`sasd-golden-restore` prüft Manifest-Prüfsumme und separaten Checksum-Datensatz, kontrolliert Archivnamen, lehnt Traversal, absolute Namen, Links, Hardlinks, Device-Nodes und FIFOs ab und extrahiert zunächst in ein privates temporäres Verzeichnis. Danach wird es in ein Ziel verschoben, das vorher nicht existieren darf. `--dry-run` führt alle Prüfungen ohne Extraktion aus.

Das Ziel muss ein neues Verzeichnis unter einem vertrauenswürdigen Laborverzeichnis sein. Das Programm besitzt absichtlich keinen `/dev`-Zielpfad, keinen Raw-Image-Modus, keine Mount-/Partitionierungsfunktion und keine Bootloader-Installation. Host-Personalisierung bleibt ein separater Vorgang.
