# Ganglia-Offline-Kandidat

English: [English version](ganglia.md)

Ganglia ist ein späteres Profil und gehört nicht zur Basis von 1999. Als
konkretes Forschungsziel ist Ganglia 3.1.1 (Wien) gewählt, veröffentlicht im
September 2008. Das offizielle Archiv führt 3.1.1 am 8. September 2008 und
3.1.2 am 28. Januar 2009; die Projekthistorie nennt 3.1.0 und 3.1.1 für 2008.
Das belegt ein zeitlich passendes Ziel, aber keine native Parserabnahme.

Die historische Architektur trennt gmond auf Clusterknoten von gmetad auf
Sammelknoten. gmond kündigt Clusterzustände per Multicast oder Unicast an,
empfängt sie und stellt eine XML-Sicht bereit. gmetad fragt Datenquellen ab,
aggregiert XML und speichert numerische, veränderliche Messwerte traditionell
mit RRDtool. Cluster können zu Grids verbunden werden.

`bin/sasd-config-ganglia` ordnet aktiven Rechnern höchstens eine
`ganglia-*`-Inventargruppe als Cluster zu. Mehrdeutige Mitgliedschaften
werden zurückgewiesen. Hosts ohne eine solche Gruppe erhalten das
Kandidatenprofil `default`. Allgemeine Inventargruppen bleiben Hostgruppen.
Eine ausdrücklich angegebene Lifecycle-Datei muss lesbar und gültig sein.
Der Lifecycle ist eine Zustandsprojektion, in der Hosts ohne Eintrag aktiv
bleiben.

Für einen Cluster erzeugt `--gmond-out gmond.conf` genau diese Datei.
Bei mehreren Clustern entstehen separate Dateien wie
`gmond.ganglia-west.conf` und `gmond.ganglia-east.conf`, je mit einer
Clusterdefinition und Mitgliederliste. Das Deployment-Manifest erfasst die
einzelnen Dateien. `--gmetad-out` listet die offenen Datenquellen als
Kommentare. TCP-Endpunkte sowie Multicast- oder Unicast-Kanäle müssen vor
der nativen Abnahme anhand der tatsächlichen Topologie festgelegt werden.
Für eine neue Topologie ein frisches Staging-Verzeichnis verwenden. Das
Deployment kopiert die im Manifest erfassten Dateien und löscht keine
veralteten Kandidaten im Ziel.

`bin/sasd-ganglia-metric --hosts FILE --roles FILE --input FILE` liest
synthetische TSV-Beobachtungen mit sieben Feldern. `--state FILE` verwendet
dieselbe Lifecycle-Projektion wie der Generator.

    host<TAB>cluster<TAB>epoch<TAB>metric<TAB>value<TAB>unit<TAB>type

| Metrik | Einheit | Typ | Zulässiger Bereich |
| --- | --- | --- | --- |
| `cpu` | `percent` | Gauge | 0 bis 100, bis zu sechs Nachkommastellen |
| `mem` | `bytes` | Gauge | 0 bis 999999999999999, ganzzahlig |
| `load` | `count` | Gauge | 0 bis 999999, bis zu sechs Nachkommastellen |
| `net_rx`, `net_tx` | `bytes` | Counter | 0 bis 999999999999999, ganzzahlig |

CPU-Auslastung ist ein Prozentwert. Load Average zählt ausführbare bzw. auf
Arbeit wartende Prozesse entsprechend der Quellplattform. Netzwerkwerte sind
absolute Zähler. Übertragungsraten benötigen eine eigene Auswertung von
Differenzen, Zeiten und Zählerrücksetzungen.

Die Batchgrenzen sind 262144 Byte Eingabe, 2048 Byte pro Zeile ohne LF und
4096 Beobachtungen. Je Host und Metrik müssen die Zeitstempel im Batch
streng steigen. Bei einem Format-, Typ-, Bereichs- oder Identitätsfehler
entsteht keine Ausgabe. Ein gültiger Batch liefert je Beobachtung die
Originalfelder mit vorangestelltem `OK` oder `UNKNOWN` und angehängtem
`FIXTURE`. Zukünftige Beobachtungen und ältere als `--freshness SECONDS`
(Standard 900) ergeben relativ zu `--now EPOCH` bzw. der aktuellen Zeit
`UNKNOWN`. Bei UNKNOWN dienen die ausgegebenen Rohwerte der Diagnose.

Geprüfte Quellen:

- [Ganglia-Projekthistorie](https://ganglia.github.io/blog/archives/)
- [Ganglia-Core-Archiv](https://sourceforge.net/projects/ganglia/files/ganglia%20monitoring%20core/)
- [Ganglia-Architekturbeschreibung](https://github.com/fastly/ganglia/blob/master/ganglia.pod)
- [Projekt- und BSD-Lizenzangabe](https://github.com/ganglia)

Die Architekturbeschreibung belegt das Produktmodell, nicht die Parserannahme
der erzeugten Kandidaten durch 3.1.1. Native Ausführung, XML-Parser,
Multicast/Unicast, gmetad-Speicherung und RRD-Lebenszyklus sind NOT TESTED.
