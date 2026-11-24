# MRTG-Adapter: lokale Zählereingabe

English: [English version](README.md)

MRTG kann ein externes Kommando verwenden, das vier Zeilen liefert: Eingangs-Zähler, Ausgangs-Zähler, Betriebszeit und Gerätename. `bin/sasd-mrtg-counter` implementiert diese **dokumentierte externe Schnittstelle**, ohne SNMP-Bibliotheken einzubetten oder MRTG-Code zu kopieren.

Die vorgeschlagene `mrtg.cfg.example` enthält absichtliche Platzhalter. `PATH_TO_CHECKOUT` und `PATH_TO_MRTG_WORKDIR` in einer Wegwerf-Umgebung durch absolute Pfade ersetzen. Das externe Kommando vor dem Aufruf von MRTG allein ausführen. Das Fixture enthält kumulative Bytezähler, keine Bandbreitenwerte; MRTG berechnet Raten durch regelmäßiges Abfragen.

    ./bin/sasd-mrtg-counter --input fixtures/mrtg/ifcounters.tsv

Dies ist kein SNMP-Poller. Echte Routerdatenerfassung und Diagrammerzeugung durch MRTG bleiben separate Abnahmethemen. Keine echte SNMP-Community und keinen Produktionsrouter verwenden, bevor ein begrenzter lesender Poller geprüft wurde.

Dokumentation: https://mrtg.org/mrtg/doc/mrtg-reference.en.html
