# Offline-Monitoring für Datenbankgesundheit

English: [English version](database.md)

SASD Freeware ist für `db-probe`, `db-health`, `db-activity` und
`db-storage` zuständig. Dieser Adapter führt synthetische Beobachtungen in
den gemeinsamen SASD-Monitoring-Zyklus ein. Der Test verwendet ein
Wegwerfpräfix und benötigt keinen Datenbankclient.

## Instanzregister und Laborkonfiguration

`site/databases.tsv` enthält Instanz, Host, Produkt, erwartete Version,
Diagnoseprofil und Lebenszyklus. Der stabile Check `db_<instanz>` wird aus
diesem Register abgeleitet und ist genau dem angegebenen Host zugeordnet.
Instanznamen folgen der gemeinsamen Bezeichnergrammatik und sind höchstens
29 Zeichen lang. Doppelte Instanznamen und Kollisionen mit statischen Checks
führen auch bei abweichender Groß-/Kleinschreibung zu einem Fehler. Die
erwartete Version kann eine Versionsfamilie oder einen exakten Stand angeben.
Das Diagnoseprofil ist hier beschreibend.

In einem Wegwerfpräfix das Register nach `etc/databases.tsv` kopieren und
`offline_databases=databases.tsv` in einer Kopie der installierten
Konfiguration ergänzen. Diese Konfiguration mit
`sasd-monitor-config --check` prüfen. Die eingecheckte Standardvorlage
enthält diese Option nicht. In `site/checks.tsv` sind keine doppelten
Instanzeinträge nötig.

Der implizite Host-Lifecycle-Pfad ist der Inventarname mit der Endung
`.state`. Eine fehlende implizite Datei entspricht einer leeren Projektion.
Eine explizit mit `--state` angegebene, fehlende, unlesbare oder beschädigte
Datei führt zur Ablehnung. Hosts ohne Eintrag in einer gültigen sparsamen
Projektion behalten ihren Inventarstandard. Deaktivierte und entfernte
Hosts oder Instanzen nehmen keine Datenbankbeobachtung an. Ihre bisherige
Historie bleibt erhalten.

## Beobachtungsvertrag

Die erste Zeile lautet `SASD-DB-HEALTH-1`. Die folgenden Schlüssel stehen
je einmal in einer `key=value`-Zeile. Zulässig sind druckbare ASCII-Werte
von 1–240 Byte. Die Eingabe ist auf insgesamt 4096 Byte begrenzt.
Unbekannte Schlüssel und Steuerzeichen führen zur Ablehnung.

| Pflichtschlüssel | Zulässige Bedeutung |
| --- | --- |
| `instance`, `host` | Exakte Identitäten aus dem Register |
| `product`, `version` | `mariadb`, `mysql` oder `postgresql` mit ein- bis dreiteiliger numerischer Version |
| `source`, `diagnostic` | `OFFLINE` und `db-health` |
| `observed_at` | UTC-Epochensekunden, 1–15 Ziffern |
| `scope` | `server` für MySQL/MariaDB, `cluster` für PostgreSQL |
| `connections`, `active`, `uptime` | Nichtnegative ganze Zahlen mit bis zu 15 Stellen oder `unknown`. Uptime in Sekunden |
| `visibility` | `complete`, `partial` oder `unavailable` |

Das optionale `result` lautet `ok` (Standard für bestehende Fixtures)
oder `failed`. Aktive PostgreSQL-Client-Backends bilden eine Teilmenge
aller Client-Backends. MySQL/MariaDB liefern nicht atomar erfasste
Serverstatus-Zähler. Die PostgreSQL-Beziehung wird deshalb ausschließlich
für PostgreSQL geprüft. Freeware dokumentiert diese Definitionen am
Referenzcommit und setzt für seine PostgreSQL-Diagnose mindestens Version
10 voraus. [Freeware-Spezifikation für db-health](https://github.com/SASD-Sysadmin/freeware/blob/73074c6be9cef3e351aeaa28881653fdaadc9ff2/docs/commands/db-health.de.md)

| Produkt | Synthetisch akzeptierte Familie | Offline geprüftes Beispiel | Native SASD-Client-/Serverabnahme |
| --- | --- | --- | --- |
| MariaDB | 10.11 | 10.11.6 | NOT TESTED |
| MySQL | 8.0 | 8.0.36 | NOT TESTED |
| PostgreSQL | 15 | 15.4 | NOT TESTED |

Andere Versionen bleiben auch bei gültiger Syntax und passendem
Registereintrag UNKNOWN. Historische Datenbank- und Plattformabnahmen
bleiben offen.

## Status, Import und Bewertung

Für eine Gesundheitsbewertung sind `--warn-active N` und
`--crit-active N` gemeinsam anzugeben. Es gilt `0 <= warn < crit`.
Gleichheit löst die jeweilige Schwelle aus. Die gleiche Verbindungszahl
kann je nach Politik zu verschiedenen Bewertungen führen. Ohne
Bewertungspolitik bleiben auch vollständige Beobachtungen UNKNOWN.
Veraltete Evidenz (standardmäßig älter als 900 Sekunden), nicht unterstützte
Versionen, unvollständige Sichtbarkeit, fehlende Messwerte und
fehlgeschlagene Diagnosen ergeben für zugelassene Instanzen ebenfalls UNKNOWN.

    host<TAB>check<TAB>color<TAB>message<TAB>observation_epoch

Der Adapter liefert für eine zulässige Beobachtung eine validierte Zeile.
Die Meldung enthält Quellmarker, Diagnose, Instanz und Grund in einem
einzigen Feld. Die Status-Exits 0/1/2/3 entsprechen
green/yellow/red/purple. Nicht autorisierte Identitäten, ungültiges Format,
zukünftige Zeitpunkte und unbrauchbare Lifecycle-Evidenz ergeben Exit 3
ohne Datensatz. Ohne letzte Beobachtung meldet der gemeinsame Zyklus
UNKNOWN. Ältere Beobachtungen können neuere nicht ersetzen.

`sasd-monitor-import --source offline-db` übernimmt diese Zeilen mit
der aktivierten Laborkonfiguration. Der Import verlangt einen expliziten
Messzeitpunkt spätestens zu `--received-at`, den Adaptermarker und die
exakte Host-/Checkbindung. Die Laborquelle kann ausschließlich eigene
Beobachtungen ersetzen. Wiederholter Import derselben Zeile behält ihren
Messzeitpunkt. Die vom Betreiber angegebene Quelle dokumentiert die Herkunft.
Sie authentifiziert den Produzenten nicht. Ein Wegwerfpräfix mit isolierten
Pfaden für Zustand, Historie, Betriebsannotationen und Bericht verwenden.

Der fünfspaltige Eingang erhält den Messzeitpunkt für Reihenfolge und
Frische. Der Import meldet seinen Zeitpunkt, der Zyklus speichert seinen
Bewertungszeitpunkt und das sechsfeldrige Latest-Format enthält den
Zeitpunkt der jüngsten angenommenen Beobachtung. Ein getrennter
dauerhafter Empfangszeitpunkt und der Zeitpunkt der letzten erfolgreichen
Messung über spätere UNKNOWN-Beobachtungen hinweg bleiben offen. Zustandswechsel
bleiben nach den vorhandenen Aufbewahrungsregeln in der Historie verfügbar.

`tests/database.sh` prüft zwei Instanzen desselben Hosts über Import,
Latest-Zustand, Zyklus, getrennte Statuswechsel, Quittierung,
Alarmierungsbewertung und HTML-Bericht. Das
[integrierte Site-Labor](../../examples/sasd-integrated-site-lab.sh)
importiert beide Fixtures und zeigt ihre Messzeitpunkte. Native SQL-Clients,
Server, TLS und Transport benötigen eine separate Abnahme.

## Historische Produktkandidaten

`--database-config DATEI` ergänzt bei beiden klassischen Generatoren einen
Dienst je zugelassener Instanz. Der aus Makros gebildete Argumentvektor
verweist auf die aktivierte SASD-Laborkonfiguration und ruft den gemeinsamen
Adapter auf. Der Adapter liest das kanonische Ergebnis des Zyklus und
prüft die Frische erneut zum Plugin-Zeitpunkt. Fehlender Zustand,
veraltete Beobachtung, fremde Quelle und nach der Generierung entfernte
Ziele liefern UNKNOWN. Der Kandidat verwendet die exakte Zuordnung von Host
und Dienst `db_<instanz>` und erhält die Exit-Codes 0/1/2/3.

    bin/sasd-db-status-export --config DATEI --product bigbrother
    bin/sasd-db-status-export --config DATEI --product bigsister

Dies sind synthetische Prüfdatensätze für die beiden bestehenden
SASD-Schnittstellen. Big Brother gibt `host.check color (epoch) message`
aus. Big Sister verlangt das vorangestellte Token `status`. Ein gültiger
Messzeitpunkt aus dem kanonischen Zustand bleibt erhalten. Beide Exporte
bewahren getrennte Checks und UNKNOWN. Die Ausgabe verbleibt außerhalb
der Daemons und ändert den kanonischen Zustand nicht.

## Numerische Kandidaten

Für einen geprüften Snapshot `--instance ID` mit `--format mrtg` oder
`--format rrd` anstelle der Gesundheitsoptionen angeben. Die Auswahl bindet
die Ausgabe an eine Instanz und bewertet die Messqualität unabhängig von
Gesundheitsschwellen.

| Metrik | Einheit | Zeitreihentyp |
| --- | --- | --- |
| `connections` | Verbindungen oder Client-Backends | Gauge |
| `active` | Aktive Sitzungen oder Client-Backends | Gauge |
| `uptime` | Sekunden seit Server- oder Postmaster-Start | Gauge |

Uptime ist eine verstrichene Dauer, die beim Neustart zurückgesetzt werden
kann. Das externe MRTG-Target gibt die beiden Gauges für Verbindungen und
Aktivität, Uptime und die Kennung `host/instanz` in vier Zeilen aus. Das
Target benötigt die Option `gauge`, eine passende Obergrenze und bleibt
ohne `unknaszero`. Mit vertrauenswürdigen Literalpfaden und dem regulären
Abfrageintervall arbeiten. Ein simulierter `--now`-Wert ist dem Labortest
vorbehalten. Bei fehlender oder veralteter Evidenz endet das Programm ohne
Gauge-Ausgabe. MRTG verwendet die Abfragezeit. [MRTG-Referenz für externe Targets](https://mrtg.org/mrtg/doc/mrtg-reference.en.html)

Der RRD-Modus gibt `host<TAB>check<TAB>epoch:connections:active:uptime`
aus. Eine zugelassene Beobachtung ohne verfügbare Messwerte ergibt
`U:U:U` und Exit 3. Bei abgewiesener Identität oder fehlerhaftem Format
entsteht kein Sample. Nur aktuelle Samples und gegebenenfalls ausdrücklich
vorgesehene UNKNOWN-Samples in Zeitreihenfolge an den Wrapper übergeben.

    bin/sasd-rrd-cycle create-database LAB_RRD_DIR HOST db_INSTANZ START_EPOCH
    bin/sasd-rrd-cycle update-database LAB_RRD_DIR SAMPLE.tsv

Ein vorhandenes Wegwerfverzeichnis mit absolutem Pfad und einen Schreiber
je Instanzdatei verwenden. Der Startzeitpunkt muss vor der ersten Messung
liegen. Der Wrapper benennt die Datei `HOST.db_INSTANZ.rrd` und übergibt den
Messzeitpunkt mit explizitem Datasource-Template. Der Schritt beträgt 300
Sekunden und der Heartbeat 600 Sekunden. Die Aufbewahrung umfasst 24 Stunden
mit 5-Minuten-AVERAGE sowie 7 Tage mit stündlichem AVERAGE und MAX. Bei der
Konsolidierung gilt ein Unknown-Anteil von 0,5. [RRDtool-Referenz für create](https://oss.oetiker.ch/rrdtool/doc/rrdcreate.en.html) · [RRDtool-Referenz für update](https://oss.oetiker.ch/rrdtool/doc/rrdupdate.en.html)

`tests/database-products.sh` führt erzeugte Plugin-Argumentvektoren aus,
liest beide synthetischen Exporte über die bestehenden Parser ein, prüft die
vier MRTG-Target-Zeilen und verifiziert die RRDtool-Argumente mit einem lokalen
Testprogramm. Native Parser, Benachrichtigung, Grafiken und historische
Produktpakete benötigen weiterhin ihre Abnahme.
