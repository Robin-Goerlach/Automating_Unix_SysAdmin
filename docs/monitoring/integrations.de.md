# M1-Integrationen und spätere Adapter

English: [English version](integrations.md)

## MRTG

`bin/sasd-monitor-mrtg` erzeugt eine prüfbare Kandidatenkonfiguration mit einem Ziel je freigegebenem Rechner und Messwert. Jedes Ziel verweist auf einen lokalen `sasd-mrtg-counter`-Pfad; SNMP-Adressen, Communities und Zugangsdaten werden nicht eingebettet. Native MRTG-Grammatik und Diagrammerzeugung sind nicht abgenommen.

## RRDtool

`rrd_dir` reserviert einen Bereich für Messwerte. `sasd-rrd-cycle` bleibt der ausdrückliche RRDtool-Wrapper. M1 erzeugt, aktualisiert, überschreibt oder löscht keine RRD-Datenbanken automatisch. Ein echter Lebenszyklus benötigt eine separate Versionsprüfung.

## NetSaint, Nagios und Ganglia

M1 besitzt den kanonischen lokalen SASD-Zustand und die Historie. Künftige Adapter können Beobachtungen über begrenzte Dateien exportieren oder importieren. NetSaint gehört in das Profil 1999; Nagios und Ganglia sind spätere Profile. Kein natives Protokoll und kein Daemon werden hier implementiert.

## CFEngine

Das R2-`sasd-site-audit` bleibt eine unabhängige lokale Prüfung. M1 importiert sein Vierfeld-Ergebnis wie jede andere lokale Beobachtung. M1 emuliert keine CFEngine-Klassen und behauptet keine native CFEngine-1-Ausführung.
