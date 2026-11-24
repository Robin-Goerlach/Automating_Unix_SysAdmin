# SASD Automating Unix SysAdmin

[English](README.md) | **Deutsch** | [Roadmap](docs/ROADMAP.md) | [Architektur](docs/ARCHITECTURE.md)

Eine eigenständig entwickelte SASD-Sammlung für klassische Unix-Systemadministration. Ausgangspunkt ist ein historisch plausibler Betriebsstand von **1999**, ergänzt durch eine Entwicklungslinie von den 1980ern bis zu den Automatisierungstechniken der Jahre 2002–2009.

**Das Projekt entsteht heute; es ist kein behaupteter Original-Quellcode aus den 1980er- oder 1990er-Jahren.** CFEngine, MRTG und RRDtool sollen als externe Programme integriert werden. Big Brother dient als historische Inspiration für einen eigenen lokalen Statusspeicher, nicht als kopiertes Protokoll.

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
- bin/sasd-site-inventory – ein tabellarisches, fiktives Standortinventar prüfen und abfragen.
- bin/sasd-site-classes – Rollen in unabhängige SASD-Auswahlklassen auflösen.
- bin/sasd-site-audit – rollenbezogene Soll-Dateien lesend mit sasd-config-drift vergleichen.
- bin/sasd-monitor-config – zentrale Monitoring-Konfiguration ohne Shell-Auswertung prüfen.
- bin/sasd-monitor-hosts – überwachte R2-Hosts auflisten und prüfen.
- bin/sasd-monitor-import – lokale Statusmeldungen validieren und speichern.
- bin/sasd-monitor-cycle – Zustände, Frische und begrenzte Historie berechnen.
- bin/sasd-monitor-report – statisches HTML für den aktuellen Zustand erzeugen.
- bin/sasd-monitor-mrtg – eine zu prüfende MRTG-Kandidatenkonfiguration erzeugen.

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

Das R2-Labor liegt unter [site/README.md](site/README.md). Die Adressen aus `192.0.2.0/24` sind nur Dokumentationswerte; es gibt keine DNS-Auflösung. Die CFEngine-1-Dateien unter [cfengine/v1](cfengine/v1/README.md) sind weiterhin unbestätigte Kandidaten, solange kein originales Programm in einer passenden historischen Umgebung ausgeführt wurde.

Das M1-Monitoring-Labor ist unter [docs/monitoring/README.md](docs/monitoring/README.md) beschrieben. Es installiert sicher in ein Wegwerfverzeichnis, verarbeitet lokale Vierfeld-Statusmeldungen, erkennt veraltete Zustände, führt eine begrenzte Historie und erzeugt statisches HTML. Ein Netzwerkdienst und sichere Registrierung gehören erst zu M2.

## Entwicklungsgrundsätze

Historische Plausibilität hat Vorrang vor der bloßen Optik. Programme dürfen unabhängig voneinander entstehen und unterschiedlich aufgebaut sein. Sie benötigen aber nachprüfbare Schnittstellen, verständliche Kommentare, reproduzierbare Tests und eine dokumentierte Herkunft. Es werden weder historische Commit-Daten erfunden noch Quelltexte der Vorlagebücher kopiert.

Die beiden wichtigen Projektgrenzen: Bei 1999 bleiben wir bei CFEngine 1; CFEngine 2 gehört in die spätere Zeitstufe. Und das Buch von Campi/Bauer aus 2009 ist ein fachlicher Ideengeber für spätere Ausbauten, keine Vorlage für eine angeblich schon 1999 existierende Infrastruktur.

Details: docs/BOOK-MAP.md, docs/TIMELINE.md, docs/ROADMAP.md, docs/SECURITY.md. MIT-Lizenz nur für die eigenständig erstellten Projektbestandteile; externe Werkzeuge haben eigene Lizenzen.


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
