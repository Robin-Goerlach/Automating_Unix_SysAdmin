# Tests und Kompatibilitätsabnahme

English: [English version](TESTING.md)

## Testsuite

    make test

`make syntax` prüft Perl-Syntax, POSIX-Shell-Syntax und LF-Zeilenenden. `tests/smoke.sh` prüft synthetische `df`-Daten, privaten Statusspool, HTML-Ausgabe, Drift und das MRTG-Vierzeilenformat. `tests/classic.sh` prüft passwd, BSD-Syslog, NTP und Cron. `tests/r2-site.sh` prüft Inventar, Rollen und Audit. `tests/m1-monitoring.sh` prüft Konfiguration, Dry-run/Apply/Wiederholung, Erhalt vorhandener Dateien, Symlink-/Systempfadschutz, Import, Stale-Zustand, Escaping, MRTG-Vorlage und CRLF-Konfiguration. `tests/m2-enrollment.sh` erzeugt zwei Wegwerf-Clients, genehmigt einen, lehnt den anderen ab, prüft SSH-Signaturen, Replay-/Manipulationsschutz und Sperrung. `examples/monitoring-lab.sh` und `examples/m2-enrollment-lab.sh` sind die vollständigen Wegwerf-Demonstrationen.

Es werden weder Netzwerkzugriff noch root-Rechte benötigt.

`tests/m3-native.sh --require` führt die bereitgestellten MRTG- und RRDtool-Binaries aus und prüft HTML-/PNG-/RRD-Artefakte; ohne diese wird `SKIPPED` gemeldet. `tests/m2-ssh-integration.sh --require` führt bei vorhandenem, unprivilegiert nutzbarem `sshd` einen echten OpenSSH-Client-/Servertest aus. `tests/m4-backup.sh` und `tests/m4-operations.sh` prüfen Restore-Integrität und ablaufende Betreibersteuerung.

## Zustands- und Exit-Verträge

- `sasd-config-drift`: 0 ohne Abweichung, 1 bei fehlendem oder verändertem Ziel, 2 bei unbekanntem/unsicherem Referenzzustand.
- `sasd-status-store`: validierte Datensätze speichern oder ungleich null beenden.
- `sasd-status-board` und `sasd-monitor-report`: statisches HTML; alte oder unbekannte Zustände werden `purple`.
- `sasd-monitor-cycle`: deterministische Zeit über `--now`, keine erneute History-Zeile ohne Zustandswechsel.
- `sasd-mrtg-counter`: vier Zeilen; kein SNMP-Polling.

## Optionale und historische Abnahme

Fehlendes MRTG oder RRDtool wird als `SKIPPED` gemeldet und lässt Offline-Tests passieren. Das ist kein Nachweis einer nativen Integration. CFEngine 1, ältere Perl-Versionen, historische Unix-Systeme sowie echte MRTG-/RRDtool-Läufe benötigen eigene Versionsevidenz mit Betriebssystem, Binary, Kommando, Ausgabe und Cleanup.

Die Dokumentationsprüfung `tests/docs-pairs.pl` meldet fehlende deutsche Partner und offensichtliche defekte lokale Markdown-Links. Sie prüft nicht die semantische Übersetzungsqualität.

M2 benötigt die lokale `ssh-keygen`-Implementierung mit RSA-Erzeugung und `ssh-keygen -Y sign/verify`. `tests/m2-transport.sh` prüft das begrenzte M2.1-Framing und Ablehnungen. Die Suite beweist weiterhin keinen Live-SSH-Kanal, keine Hostschlüssel-Installation, Kontobeschränkung, Schlüsselrotation oder Produktionstransport; dafür ist ein isolierter `sshd`-Abnahmelauf erforderlich.
