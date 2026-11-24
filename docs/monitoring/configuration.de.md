# M1-Konfigurationsreferenz

English: [English version](configuration.md)

`site/monitoring.conf` ist eine begrenzte Datei im Format `key=value`. Leerzeilen und Kommentare sind erlaubt. Unbekannte oder doppelte Schlüssel, Steuerzeichen, absolute Pfade und unsichere Traversierung werden zurückgewiesen. Werte werden niemals als Shell-Code ausgewertet.

| Schlüssel | Bedeutung |
| --- | --- |
| `inventory`, `roles`, `checks` | R2-TSV-Dateien relativ zum Konfigurationsverzeichnis |
| `status_dir` | Letzte Importe und abgeleiteter Zustand |
| `history_file` | Begrenzte Ereignishistorie |
| `state_file` | Aktueller Zustand |
| `report_file` | Standardziel für statisches HTML |
| `mrtg_file` | Ziel für eine zu prüfende MRTG-Konfiguration |
| `rrd_dir` | Messwert-/RRD-Verzeichnis; keine automatische Datenbankerzeugung |
| `profile` | Profilbezeichnung, derzeit `1999` |
| `freshness` | Maximales Alter in Sekunden vor `purple` |
| `history_retention` | Maximale Zahl gespeicherter Ereignisse |
| `mrtg_command` | Freigegebener lokaler External-Target-Helfer |

Schreibfrei prüfen:

    bin/sasd-monitor-config --config site/monitoring.conf --check

Fehlende optionale Programme werden als `SKIPPED` gemeldet und scheitern nicht an Offline-Tests.
