# M4-Betrieb und Wiederherstellung

English: [English version](operations.md)

## Maintenance und Acknowledgement

Der kanonische M1-Zustand bleibt maßgeblich. Betreiber können ein bekanntes Wartungsfenster oder Problem annotieren, ohne den Gesundheitszustand zu ändern:

    bin/sasd-monitor-control --config PREFIX/etc/sasd-monitor.conf \
      --action maintenance-add --host web.lab.invalid --check disk \
      --until 2000000000 --operator admin --reason "geplante Speicherarbeit"
    bin/sasd-monitor-control --config PREFIX/etc/sasd-monitor.conf \
      --action acknowledge --host web.lab.invalid --check disk \
      --until 2000000000 --operator admin --reason "Vorfall übernommen"

Der Zyklus hängt gültige Annotationen an die Betreiber-Meldung an. Der Ablauf wird gegen die Zykluszeit `--now` geprüft. `list`, `maintenance-clear` und `acknowledgement-clear` dienen der Prüfung und Entfernung. Dateien werden unter privatem Lock atomar ersetzt. Eine Mail-/SMS-Zustellung ist nicht enthalten.

## Backup

Ein installiertes Präfix wird in ein neues, geschütztes Archiv gesichert:

    bin/sasd-monitor-backup --root /srv/sasd-monitor --out /srv/backup/sasd-monitor.tar

Das Archiv enthält Konfiguration, Inventar, Status/History, Metriken, Reports, Betriebsannotationen, öffentliche Enrollment-Daten und erzeugte MRTG-Konfiguration. `var/enrollment/keys` und private Client-Schlüssel werden absichtlich ausgeschlossen und separat geschützt. Vorhandene Archive erfordern ausdrücklich `--force`.

## Restore

Nur in ein neues Ziel wiederherstellen:

    bin/sasd-monitor-restore --archive /srv/backup/sasd-monitor.tar \
      --dest /srv/sasd-monitor-restored

Der Restore prüft eine Allowlist der Archivpfade, weist Traversal und symbolische Links zurück, extrahiert in ein temporäres Nachbarverzeichnis und verweigert vorhandene Ziele. Vor dem Ersatz eines aktiven Präfixes ist die Konfiguration über ein separat geprüftes Betreiberverfahren zu kontrollieren. `tests/m4-backup.sh` prüft erfolgreichen Restore, ausgeschlossene private Daten, fehlende/korruptе Archive und vorhandene Ziele.
