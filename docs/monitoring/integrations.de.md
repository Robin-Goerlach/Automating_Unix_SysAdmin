# M1-Integrationen und spätere Adapter

English: [English version](integrations.md)

## MRTG

`bin/sasd-monitor-mrtg` erzeugt eine prüfbare Kandidatenkonfiguration mit einem Ziel je freigegebenem Rechner und Messwert. Jedes Ziel verweist auf einen lokalen `sasd-mrtg-counter`-Pfad; SNMP-Adressen, Communities und Zugangsdaten werden nicht eingebettet. `tests/m3-native.sh --require` führt ein bereitgestelltes MRTG-Binary aus und prüft HTML-/PNG-Artefakte; der dokumentierte Lauf nutzte MRTG 2.17.10 aus einem isolierten Debian-Paket.

## RRDtool

`rrd_dir` reserviert einen Bereich für Messwerte. `sasd-rrd-cycle` bleibt der ausdrückliche RRDtool-Wrapper. M1 erzeugt, aktualisiert, überschreibt oder löscht keine RRD-Datenbanken automatisch. `tests/m3-native.sh --require` prüft Create/Update/Fetch/Graph mit RRDtool 1.7.2; dies ist zeitgenössische Evidenz und keine historische Kompatibilitätsaussage.

## NetSaint, Nagios und Ganglia

M1 besitzt den kanonischen lokalen SASD-Zustand und die Historie. Künftige Adapter können Beobachtungen über begrenzte Dateien exportieren oder importieren. NetSaint gehört in das Profil 1999; Nagios und Ganglia sind spätere Profile. Kein natives Protokoll und kein Daemon werden hier implementiert.

## CFEngine

Das R2-`sasd-site-audit` bleibt eine unabhängige lokale Prüfung. M1 importiert sein Vierfeld-Ergebnis wie jede andere lokale Beobachtung. M1 emuliert keine CFEngine-Klassen und behauptet keine native CFEngine-1-Ausführung.
