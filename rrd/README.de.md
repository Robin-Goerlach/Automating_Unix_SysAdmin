# RRDtool-Archivexperiment (Erweiterung 1999)

English: [English version](README.md)

RRDtool kann periodische Messwerte unabhängig von der HTML-Darstellung durch MRTG speichern und verdichten. Dieses Modul ist bewusst ein kleines Kommando-Wrapper und keine Neuentwicklung von RRDtool.

    ./bin/sasd-rrd-cycle create /tmp/sasd-traffic.rrd
    ./bin/sasd-rrd-cycle update /tmp/sasd-traffic.rrd 120000 340000
    rrdtool info /tmp/sasd-traffic.rrd

`create` benötigt eine noch nicht vorhandene lokale Datei. `update` benötigt eine vorhandene reguläre Datei und nichtnegative kumulative Ganzzahlen. Es werden ein Schritt von 300 Sekunden und `COUNTER`-Datenquellen verwendet. Für echte Raten mehrere Beobachtungen sammeln und Rücksetzungen sowie Zählerüberläufe berücksichtigen.

RRDtool selbst muss separat installiert werden. Die aktuelle CI prüft nur die Syntax und behauptet weder ein ausführbares RRDtool von 1999 noch ein verfügbares Diagramm.

Referenz: https://oss.oetiker.ch/rrdtool/
