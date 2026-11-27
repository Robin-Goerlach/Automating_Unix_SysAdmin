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

bin/sasd-config-ganglia leitet tatsächliche Clusteridentitäten nur aus
Inventargruppen mit dem Präfix `ganglia-` ab. Allgemeine Gruppen wie `admin`
und `lab` bleiben Rechnergruppen und werden nicht stillschweigend als Cluster
behandelt. Rechner ohne ausdrückliche Ganglia-Gruppe verwenden den
dokumentierten Cluster `default`. Der Generator erzeugt getrennte Prüfdateien
für gmond und gmetad, lässt deaktivierte und entfernte Rechner aus und
verwendet möglichst den Monitoringrechner als gmetad-Quelle. Die Dateien sind
nur Kandidaten: SASD startet keinen Daemon, bindet keinen Port, tritt keinem
Multicast bei und erzeugt keine RRD.

bin/sasd-ganglia-metric prüft ein begrenztes synthetisches TSV-Format:

    host  cluster  epoch  metric  value  unit  type

Unterstützt werden cpu, mem, load, net_rx und net_tx sowie die Typen gauge und
counter. Ungültige Identitäten, Werte, Duplikate, zeitlich rückläufige
Beobachtungen, zukünftige und veraltete Zeitpunkte werden abgewiesen oder als
UNKNOWN ausgegeben. Dies ist ein SASD-Fixtureformat und kein Ganglia-XML.
XML-Parsing und native RRDtool-Aufnahme bleiben spätere Abnahmearbeiten.

Geprüfte Quellen:

- [Ganglia-Projekthistorie](https://ganglia.github.io/blog/archives/)
- [Ganglia-Core-Archiv](https://sourceforge.net/projects/ganglia/files/ganglia%20monitoring%20core/)
- [Ganglia-Architekturbeschreibung](https://github.com/fastly/ganglia/blob/master/ganglia.pod)
- [Projekt- und BSD-Lizenzangabe](https://github.com/ganglia)

Die Architekturbeschreibung belegt das Produktmodell, nicht die Parserannahme
der erzeugten Kandidaten durch 3.1.1. Native Ausführung, XML-Parser,
Multicast/Unicast, gmetad-Speicherung und RRD-Lebenszyklus sind NOT TESTED.
