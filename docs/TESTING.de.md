# Tests und Kompatibilitätsabnahme

English: [English version](TESTING.md)

## Testsuite

    make test

`make syntax` prüft Perl-Syntax, POSIX-Shell-Syntax und LF-Zeilenenden. `tests/smoke.sh` prüft synthetische `df`-Daten, privaten Statusspool, HTML-Ausgabe, Drift und das MRTG-Vierzeilenformat. `tests/classic.sh` prüft passwd, BSD-Syslog, NTP und Cron. `tests/r2-site.sh` prüft Inventar, Rollen und Audit. `tests/m1-monitoring.sh` prüft Konfiguration, Dry-run/Apply/Wiederholung, Erhalt vorhandener Dateien, Symlink-/Systempfadschutz, Import, Stale-Zustand, Escaping, MRTG-Vorlage und CRLF-Konfiguration. `tests/m2-enrollment.sh` erzeugt zwei Wegwerf-Clients, genehmigt einen, lehnt den anderen ab, prüft SSH-Signaturen, Replay-/Manipulationsschutz und Sperrung. `examples/monitoring-lab.sh` und `examples/m2-enrollment-lab.sh` sind die vollständigen Wegwerf-Demonstrationen.

Es werden weder Netzwerkzugriff noch root-Rechte benötigt.

`tests/m3-native.sh --require` führt die bereitgestellten MRTG- und RRDtool-Binaries aus und prüft HTML-/PNG-/RRD-Artefakte; ohne diese wird `SKIPPED` gemeldet. `tests/m2-ssh-integration.sh --require` führt bei vorhandenem, unprivilegiert nutzbarem `sshd` einen echten OpenSSH-Client-/Servertest aus. `tests/m4-backup.sh` und `tests/m4-operations.sh` prüfen Restore-Integrität und ablaufende Betreibersteuerung.

## Zustands- und Exit-Verträge

- `sasd-config-drift`: 0 ohne Abweichung, 1 bei fehlendem oder verändertem Ziel, 2 bei unbekanntem/unsicherem Referenzzustand.
- `sasd-status-store`: die vollständige Eingabe vor Änderungen validieren, kooperierende Schreiber mit einem privaten Spool-Lock serialisieren und bei ungültiger Eingabe ungleich null beenden. Ein Dateisystem- oder Prozessfehler während der Rename-Phase kann weiterhin einen teilweise installierten Batch hinterlassen; vollständige Mehrdatei-Commit-Semantik wird nicht behauptet.
- `sasd-status-board` und `sasd-monitor-report`: statisches HTML; alte oder unbekannte Zustände werden `purple`.
- `sasd-monitor-cycle`: deterministische Zeit über `--now`, keine erneute History-Zeile ohne Zustandswechsel.
- `sasd-mrtg-counter`: vier Zeilen; kein SNMP-Polling.

## Optionale und historische Abnahme

Fehlendes MRTG oder RRDtool wird als `SKIPPED` gemeldet und lässt Offline-Tests passieren. Das ist kein Nachweis einer nativen Integration. CFEngine 1, ältere Perl-Versionen, historische Unix-Systeme sowie echte MRTG-/RRDtool-Läufe benötigen eigene Versionsevidenz mit Betriebssystem, Binary, Kommando, Ausgabe und Cleanup.

Die Dokumentationsprüfung `tests/docs-pairs.pl` meldet fehlende deutsche Partner und offensichtliche defekte lokale Markdown-Links. Sie prüft nicht die semantische Übersetzungsqualität. `sasd-status-store` prüft Batch-Fehler vor der ersten Änderung und serialisiert kooperierende Schreiber; Crash-Konsistenz bei mehreren Renames bleibt offen.

## Kompatibilitätsmatrix

Die aktuelle Evidenz ist bewusst eng. Der WSL-Entwicklungsrechner verwendet Perl 5.36.0 und eine zeitgenössische POSIX-Shell; `make test` ist die CI-artige Offline-Evidenz für diese Umgebung. Einige Werkzeuge verwenden Perl-Syntax nach 5.004 (unter anderem Defined-or und Substitutionsrückgabewerte), daher wird Perl 5.004 nicht als unterstützt behauptet. Für historische Unix-Systeme oder andere Perl-Versionen gilt erst nach einem archivierten Lauf mit benanntem Binary und Betriebssystem eine Kompatibilitätsaussage.

Siehe [COMPATIBILITY.de.md](COMPATIBILITY.de.md) für die Evidenztabelle und die genaue Grenze zwischen beobachtet, CI-geprüft, integrationsgeprüft und historisch bestätigt.

M2 benötigt die lokale `ssh-keygen`-Implementierung mit RSA-Erzeugung und `ssh-keygen -Y sign/verify`. `tests/m2-transport.sh` prüft das begrenzte M2.1-Framing und Ablehnungen. Die Suite beweist weiterhin keinen Live-SSH-Kanal, keine Hostschlüssel-Installation, Kontobeschränkung, Schlüsselrotation oder Produktionstransport; dafür ist ein isolierter `sshd`-Abnahmelauf erforderlich.

`tests/m5-golden.sh` und `examples/m5-golden-lab.sh` prüfen den unprivilegierten Golden-Client-Archivlebenszyklus einschließlich Audit, Dry-Run-/Apply-Grenzen, Manifest- und Checksum-Prüfung, ausgeschlossener Identitäts-/Laufzeitdaten, sicherem Restore, Schutz vor wiederholtem Capture sowie negativen Archiv-/Metadatenfällen. Der Test verwendet nur temporäre Verzeichnisse und normale Dateien.

`release/package.sh` akzeptiert eine explizite Version, einen Git-Ref und ein absolutes Ausgabeverzeichnis. Mit `--test` werden saubere Extraktion, Zeilenenden/Executable-Eigenschaften und die Offline-Tests M5–M7 geprüft. `make release-test` erzeugt denselben commitbasierten Kandidaten zweimal in getrennten Verzeichnissen und vergleicht die Archive; es erzeugt keinen Tag und kein Release. Ein Pakettest gegen `HEAD` schließt uncommittete Arbeitsbaumänderungen bewusst aus.

`tests/m6-netboot.sh` prüft die drei Offline-Konfigurationsdialekte, Profil-/Image-Zuordnung, Ablehnung doppelter MACs/IPs, Secret-Filter, TFTP-Staging mit Prüfsumme, wiederholtes Staging sowie Symlink-/Pfadfehler. `tests/m7-postinstall.sh` prüft neue Identitäten, Image-Versionsauswahl, Clone-/Reinstallations-Ablehnung, Betreiberfreigabe/-ablehnung und authentifizierte Statusübergabe. Kein Test startet einen Netzwerkdienst oder behauptet einen nativen Boot.

Das Ziel `site-test` von B prüft Inventar- und Serviceauswahl. Der R2-Fixture-Pfad deckt außerdem Host-admin, Site-config und Site-consistency ab: CRUD-Schreibvorgänge benötigen `--apply`, deaktivierte Hosts werden aus dem Staging ausgelassen, vorhandene Staging-Verzeichnisse werden abgewiesen und Profil- oder Monitoring-Inventarabweichungen schlagen sicher fehl. Das bleibt Offline-Konfigurationsprüfung und ist kein nativer Produktparser oder Deployment.
