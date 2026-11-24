# SASD-Provisionierungswerkzeuge

English: [English version](README.md)

Dieses Verzeichnis beschreibt die begrenzte Provisionierungsarbeit nach SASD 1.0. M5 wird zuerst umgesetzt: Ein ausgewählter Referenzbaum wird geprüft, als Dateisystem-TAR archiviert, mit Metadaten und Prüfsummen versehen, katalogisiert und ausschließlich in ein neues Wegwerfverzeichnis wiederhergestellt.

Die Werkzeuge erzeugen keine bootfähigen Datenträger, schreiben keine Blockgeräte, konfigurieren kein DHCP und installieren kein Betriebssystem. Netzwerkboot in M6 und Postinstallation/Enrollment in M7 sind getrennte Meilensteine und dürfen aus einem M5-Archiv nicht abgeleitet werden.

## M5-Ablauf

1. Den Referenzbaum vorbereiten oder anhalten. Ein Live-Archiv kann inkonsistent sein; bei erforderlicher Konsistenz ist ein vom Betreiber gewählter Snapshot zu verwenden.
2. `bin/sasd-golden-audit --root DIR --out REPORT --profile PROFILE` ausführen. Der Bericht unterscheidet durchgeführte von plattformspezifisch nicht durchgeführten Prüfungen.
3. `bin/sasd-golden-capture --source DIR --repository DIR --image-id ID --version VERSION --profile PROFILE --dry-run` ausführen, prüfen und danach mit `--apply` wiederholen.
4. `manifests/ID.tsv`, `checksums/ID.sha256` und `archives/ID.tar` prüfen. Anschließend `bin/sasd-golden-catalog --repository DIR --verify` ausführen.
5. Mit `bin/sasd-golden-restore --repository DIR --image-id ID --dest DIR --dry-run` und danach `--apply` in ein neues Laborverzeichnis wiederherstellen.

Capture schließt temporäre Laufzeitbäume sowie private SSH-/SASD-Identitätsdaten aus. Hostname, Netzwerkeinstellungen, Bootloader, Hardwaretreiber, SSH-Hostschlüssel und Monitoring-Identität benötigen Nacharbeiten; ein Archiv ist keine fertige Golden-Identität.

Siehe [golden-images.md](golden-images.md), [security.md](security.md) und [testing.md](testing.md). Die reproduzierbare Offline-Abnahme ist `tests/m5-golden.sh`; der Bedienablauf steht in `examples/m5-golden-lab.sh`.
