# M1 zentraler Monitoring-Server

English: [English version](README.md)

M1 ist ein lokaler, verzeichnisbasierter Monitoring-Server für das 1999-Kompatibilitätsprofil. Er besteht aus unabhängigen Perl- und POSIX-Shell-Kommandos, nicht aus einem Daemon oder einer datenbankgestützten Plattform.

## Installation

Ein Wegwerfpräfix verwenden und Schreibvorgänge ausdrücklich aktivieren:

    install/install-monitoring-server.sh \
      --prefix /tmp/sasd-monitor-lab \
      --config site/monitoring.conf --dry-run
    install/install-monitoring-server.sh \
      --prefix /tmp/sasd-monitor-lab \
      --config site/monitoring.conf --apply

Der Installer kopiert freigegebene SASD-Programme, R2-Inventar, Checks, Konfiguration und Parser. Er weist Systempräfixe und symbolische Pfadkomponenten zurück, erhält vorhandene reguläre Dateien und installiert weder Pakete noch Dienste.

## Laufzeitstruktur

Das Präfix enthält `bin/`, `etc/`, `lib/SASD/`, `var/status/`, `var/history/`, `var/metrics/`, `var/reports/`, `var/enrollment/`, `share/mrtg/` und `log/`. Laufzeitdateien sind lokale Textdateien. Das Präfix sollte nur für das Monitoringkonto beschreibbar sein.

## Ein Zyklus

Ein lokaler Produzent erzeugt den bestehenden vierfeldrigen SASD-Datensatz:

    host<TAB>check<TAB>color<TAB>message

Import, Frischebewertung und Bericht:

    bin/sasd-monitor-import --config PREFIX/etc/sasd-monitor.conf --input observations.tsv --received-at 1000 --source local
    bin/sasd-monitor-cycle --config PREFIX/etc/sasd-monitor.conf --now 1100
    bin/sasd-monitor-report --config PREFIX/etc/sasd-monitor.conf --out PREFIX/var/reports/index.html

Der M1-Import ist lokal und nur durch den vom Administrator gewählten Eingabepfad begrenzt. Er ist kein Netzwerkprotokoll und kein Enrollment.

`examples/monitoring-lab.sh` führt die vollständige Wegwerf-Demonstration aus. M2-Registrierung, Client-Bootstrap und signierter Offline-Import sind unter [enrollment.de.md](enrollment.de.md) dokumentiert. `examples/m2-enrollment-lab.sh` zeigt den positiven Ablauf; `tests/m2-enrollment.sh` prüft zwei Clients und Negativfälle.
