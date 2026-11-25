# SASD Automating Unix SysAdmin

[English](README.md) | **Deutsch** | [Roadmap](docs/ROADMAP.de.md) | [Architektur](docs/ARCHITECTURE.de.md) | [Integrierter Umfang](docs/INTEGRATED-SCOPE.de.md) | [Sicherheit](docs/SECURITY.de.md) | [Tests](docs/TESTING.de.md)

Eine eigenständig entwickelte SASD-Sammlung für Unix-Systemadministration. Ausgangspunkt ist ein Kompatibilitätsprofil für einen Unix-Stand um **1999**, ergänzt durch getrennte Profile für frühere Bourne-Shell-Umgebungen und spätere Automatisierungstechniken von 2002–2009.

**Das Projekt entsteht heute; es ist kein behaupteter Original-Quellcode aus den 1980er- oder 1990er-Jahren.** CFEngine, MRTG und RRDtool werden als externe Programme begrenzt integriert. Big Brother dient als fachlicher Vergleich; sein proprietäres Protokoll wird nicht kopiert.

## Erste ausführbare Werkzeuge

- bin/sasd-host-facts – lokale Systeminformationen, lesend.
- bin/sasd-disk-watch – Auswertung der POSIX-Ausgabe von df -kP.
- bin/sasd-config-drift – Soll-/Ist-Vergleich für Konfigurationsdateien.
- bin/sasd-status-store – datensatzweise lokale Statusablage.
- bin/sasd-status-board – statische HTML-Übersicht ohne Webserver.
- bin/sasd-mrtg-counter – vier Zeilen für einen externen MRTG-Target.
- bin/sasd-rrd-cycle – optionaler Aufruf von RRDtool für eine Zählerdatenbank.
- bin/sasd-passwd-audit – lokale Passwortdatei ohne Kennwortausgabe prüfen.
- bin/sasd-syslog-count – klassische Syslog-Meldungen nach Programm zählen.
- bin/sasd-ntp-sources – NTP-Quellen aus Konfigurationsdatei auslesen.
- bin/sasd-cron-inspect – klassische Benutzer-Crontabs ohne Befehlsausführung prüfen.
- bin/sasd-bb-hosts-lint – historisches Big-Brother-Hostinventar ohne Netzwerkzugriff prüfen.
- bin/sasd-site-inventory – ein tabellarisches Standortinventar prüfen und abfragen.
- bin/sasd-site-classes – Rollen in unabhängige SASD-Auswahlklassen auflösen.
- bin/sasd-site-audit – rollenbezogene Soll-Dateien lesend mit sasd-config-drift vergleichen.
- bin/sasd-monitor-config – zentrale Monitoring-Konfiguration ohne Shell-Auswertung prüfen.
- bin/sasd-monitor-hosts – überwachte R2-Hosts auflisten und prüfen.
- bin/sasd-monitor-import – lokale Statusmeldungen validieren und speichern.
- bin/sasd-monitor-cycle – Zustände, Frische und begrenzte Historie berechnen.
- bin/sasd-monitor-report – statisches HTML für den aktuellen Zustand erzeugen.
- bin/sasd-monitor-mrtg – eine zu prüfende MRTG-Kandidatenkonfiguration erzeugen.
- bin/sasd-monitor-control – ablaufende Maintenance- und Acknowledgement-Annotationen speichern.
- bin/sasd-monitor-backup / restore – freigegebene Monitoringdaten sichern und wiederherstellen.
- bin/sasd-enrollment – Registrierungsanträge genehmigen, verwerfen und sperren.
- bin/sasd-node-status – bestehende Statusdatensätze mit SSH signieren.
- bin/sasd-monitor-auth-import – genehmigte Identität prüfen und signierte Statusdaten importieren.
- install/install-sasd-client.sh – einen Wegwerf-Client und Registrierungsantrag vorbereiten.
- bin/sasd-host-admin – das zentrale Hostinventar mit explizitem Apply verwalten.
- bin/sasd-site-config – Host-/Service-Auswahl reproduzierbar in ein Staging-Verzeichnis schreiben.
- bin/sasd-site-consistency – aktive Auswahl lesend gegen das Monitoringmodell prüfen.

Die integrierte Infrastruktur, ihre Grenzen und der Status der Checkpoints sind in [docs/INTEGRATED-SCOPE.de.md](docs/INTEGRATED-SCOPE.de.md) beschrieben. `sasd-site-consistency` prüft zusätzlich die aktive Auswahl gegen `site/monitoring.conf`. Die neuen B-Werkzeuge starten keine Dienste, installieren keine Pakete und genehmigen kein Enrollment.

## Schnellstart

    git clone https://github.com/Robin-Goerlach/Automating_Unix_SysAdmin.git
    cd Automating_Unix_SysAdmin
    make test
    ./bin/sasd-disk-watch --host lab-host --input fixtures/df/healthy.txt
    ./bin/sasd-config-drift --root fixtures/config/actual --golden fixtures/config/golden --manifest fixtures/config/manifest.tsv

Eine lokale Statusseite wird beispielsweise so erzeugt:

    mkdir -p /tmp/sasd-unix-status
    ./bin/sasd-status-store --spool /tmp/sasd-unix-status --input fixtures/status/disk.tsv
    ./bin/sasd-status-board --spool /tmp/sasd-unix-status --out /tmp/sasd-unix-status/index.html

Die Beispieldaten sind synthetisch. Ein Produktivsystem wird dadurch nicht untersucht oder verändert.

Das R2-Rechnerinventar ist unter [site/README.de.md](site/README.de.md) beschrieben. Die Adressen aus `192.0.2.0/24` sind Dokumentationswerte; es gibt keine DNS-Auflösung. Die CFEngine-1-Dateien unter [cfengine/v1/README.de.md](cfengine/v1/README.de.md) sind unbestätigte Kandidaten, solange kein originales Programm in einer passenden Umgebung ausgeführt wurde.

Der M1-Monitoring-Server ist unter [docs/monitoring/README.de.md](docs/monitoring/README.de.md) beschrieben. Er installiert sicher in ein Wegwerfverzeichnis, verarbeitet lokale Vierfeld-Statusmeldungen, erkennt veraltete Zustände, führt eine begrenzte Historie und erzeugt statisches HTML. M2-Registrierung und der feste M2.1-SSH-Transport sind unter [docs/monitoring/enrollment.de.md](docs/monitoring/enrollment.de.md) und [docs/monitoring/transport.de.md](docs/monitoring/transport.de.md) beschrieben; SASD fügt keinen Listener hinzu. Der genaue V1.0-Umfang steht in [docs/RELEASE-1.0.de.md](docs/RELEASE-1.0.de.md). Die M5–M7-Provisionierungsarbeit ist unter [docs/provisioning/README.de.md](docs/provisioning/README.de.md) beschrieben; die aktuellen Offline-Werkzeuge schreiben niemals Blockgeräte und genehmigen kein Monitoring automatisch.

## Produktentwicklung

- 1980er-Schicht: Bourne-Shell, sed, awk, Cron, Syslog und einfache Textinventare.
- Frühe/mittlere 1990er: Perl 4/5, Rechnerverwaltung, Backups, lokale Policyprüfungen und optional CFEngine 1.
- Späte 1990er: MRTG, RRDtool, unabhängige Statusberichte und Soll-Konfigurationen.
- 2002–2009: CFEngine 2, FAI/Kickstart/JumpStart, sicheres SSH, Apache-Verteilung, Nagios/NRPE und Ganglia als getrennte spätere Profile.

Die Module müssen kein gemeinsames Framework bilden. Unterschiede zwischen den Werkzeugen bleiben zulässig, solange Schnittstellen, Tests und Sicherheitsgrenzen dokumentiert sind.

## Entwicklungsgrundsätze

Technische Klarheit und nachprüfbare Kompatibilität haben Vorrang vor bloßer Optik. Programme dürfen unabhängig voneinander entstehen und unterschiedlich aufgebaut sein. Sie benötigen aber klare Schnittstellen, verständliche Kommentare, reproduzierbare Tests und dokumentierte Herkunft. Es werden weder historische Commit-Daten erfunden noch Quelltexte der Vorlagebücher kopiert.

Die beiden wichtigen Projektgrenzen: Bei 1999 bleiben wir bei CFEngine 1; CFEngine 2 gehört in die spätere Zeitstufe. Und das Buch von Campi/Bauer aus 2009 ist ein fachlicher Ideengeber für spätere Ausbauten, keine Vorlage für eine angeblich schon 1999 existierende Infrastruktur.

Details: [Themenübersicht](docs/BOOK-MAP.de.md), [Zeitprofile](docs/TIMELINE.de.md), [Roadmap](docs/ROADMAP.de.md), [Sicherheit](docs/SECURITY.de.md), [Provenienz](docs/PROVENANCE.de.md). Die MIT-Lizenz gilt nur für eigenständig erstellte Projektbestandteile; externe Werkzeuge haben eigene Lizenzen.

## Aktuelle Grenzen

CI läuft auf einem aktuellen Linux-System und prüft nur Offline-Verhalten. CFEngine-1-Syntax, ältere Perl-Interpreter, echte MRTG-Diagramme, der RRDtool-Datenbanklebenszyklus und ein Live-SSH-Transport sind auf historischen Betriebssystemen oder in Produktionsnetzen noch nicht abgenommen. Beispiele sind kontrollierte Verwaltungsbeispiele und keine Produktionsanleitung.


### Unix-Zeilenenden unter Windows/WSL

Alle Unix-Skripte müssen **LF** statt **CRLF** verwenden. Ansonsten kann `sh` trotz scheinbar korrektem `if`/`fi` einen Fehler wie `Syntax error: end of file unexpected (expecting "then")` melden.

Die Datei [.gitattributes](.gitattributes) legt LF für Textdateien beim Git-Checkout fest; [.editorconfig](.editorconfig) hilft bei der Editor-Einstellung. Bereits vorhandene lokale CRLF-Dateien werden beim Aktualisieren nicht zwingend automatisch konvertiert.

```sh
git status --short
file bin/sasd-host-facts
sed -n '1,20l' bin/sasd-host-facts
# Nur bei bestätigten CRLF-Zeilenenden:
sed -i 's/\r$//' bin/sasd-host-facts
make test
```

Falls `make test` weitere CRLF-Dateien meldet, nur diese gezielt auf LF normalisieren. `git reset --hard` und `git clean` sind dafür unnötig und können lokale Änderungen löschen.
