# Tests und Kompatibilitätsabnahme

English: [English version](TESTING.md)

## Testsuite

    make test

`make syntax` prüft Perl-Syntax, POSIX-Shell-Syntax und LF-Zeilenenden. `tests/smoke.sh` prüft synthetische `df`-Daten, privaten Statusspool, HTML-Ausgabe, Drift und das MRTG-Vierzeilenformat. `tests/classic.sh` prüft passwd, BSD-Syslog, NTP und Cron. `tests/r2-site.sh` prüft Inventar, Rollen und Audit. `tests/m1-monitoring.sh` prüft Konfiguration, Dry-run/Apply/Wiederholung, Erhalt vorhandener Dateien, Symlink-/Systempfadschutz, Import, Stale-Zustand, Escaping, MRTG-Vorlage und CRLF-Konfiguration. `examples/monitoring-lab.sh` ist die vollständige Wegwerf-Demonstration.

Es werden weder Netzwerkzugriff noch root-Rechte benötigt.

## Zustands- und Exit-Verträge

- `sasd-config-drift`: 0 ohne Abweichung, 1 bei fehlendem oder verändertem Ziel, 2 bei unbekanntem/unsicherem Referenzzustand.
- `sasd-status-store`: validierte Datensätze speichern oder ungleich null beenden.
- `sasd-status-board` und `sasd-monitor-report`: statisches HTML; alte oder unbekannte Zustände werden `purple`.
- `sasd-monitor-cycle`: deterministische Zeit über `--now`, keine erneute History-Zeile ohne Zustandswechsel.
- `sasd-mrtg-counter`: vier Zeilen; kein SNMP-Polling.

## Optionale und historische Abnahme

Fehlendes MRTG oder RRDtool wird als `SKIPPED` gemeldet und lässt Offline-Tests passieren. Das ist kein Nachweis einer nativen Integration. CFEngine 1, ältere Perl-Versionen, historische Unix-Systeme sowie echte MRTG-/RRDtool-Läufe benötigen eigene Versionsevidenz mit Betriebssystem, Binary, Kommando, Ausgabe und Cleanup.

Die Dokumentationsprüfung `tests/docs-pairs.pl` meldet fehlende deutsche Partner und offensichtliche defekte lokale Markdown-Links. Sie prüft nicht die semantische Übersetzungsqualität.
