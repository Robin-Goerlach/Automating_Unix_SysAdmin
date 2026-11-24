# SASD-1.0-Umfang und Abnahme

English: [English version](RELEASE-1.0.md)

Status: Die Pflichtnachweise sind für Commit `7920cad` vollständig. Der annotierte Tag `v1.0.0` und die GitHub-Veröffentlichung sind die verbleibenden Publikationsschritte.

## Enthalten und verifiziert

- R0, R2, M1 und das Offline-M2-Enrollment bleiben durch `make test` und Wegwerflabore abgedeckt.
- M2.1-Client-/Receiver-Transport, begrenztes Framing, strikte SSH-Optionen, Forced-Command-Vertrag, Offline-Negativtests und Installerintegration.
- MRTG-External-Target-Vertrag und nativer MRTG-2.17.10-Lauf mit HTML-/PNG-Artefakten.
- RRDtool-1.7.2-Lebenszyklus mit deterministischen Zählerwerten: Erzeugen, Aktualisieren, Fetch und Graph mit geprüftem PNG.
- Wegwerf-Installer für Server und Client mit Dry-Run-/Apply-Schranke und Erhalt bestehender Konfiguration.
- Dateibasierte Maintenance- und Acknowledgement-Einträge mit Ablauf, Operator/Grund und sichtbarer Statusannotation.
- Dateibasiertes Backup/Restore für Konfiguration, Inventar, Status/History, Metriken, Reports, Betriebsannotationen, öffentliche Enrollment-Daten und MRTG-Konfiguration. Private Enrollment-Schlüssel werden ausgeschlossen.
- Englische/deutsche Betriebsdokumentation, Negativtests und reproduzierbare Offline-/native Harnesses.

## Enthalten mit Einschränkungen

- Der Live-SSH-Transport ist im GitHub-Actions-Lauf `45392269226` mit `/usr/sbin/sshd` abgenommen: erfolgreicher Transfer und Ablehnung mit leerer `known_hosts`-Datei wurden beobachtet. Die lokale unprivilegierte WSL-Sandbox kann den ausgepackten Daemon weiterhin nicht binden und ist daher nicht die Quelle des nativen Netzwerknachweises.
- Die native M3-Evidenz verwendet Debian-Paketversionen 2.17.10 und 1.7.2, die unter `/tmp` ausgepackt wurden. Das ist kein Nachweis historischer Kompatibilität und pollt keine Produktionsschnittstelle.
- Maintenance und Acknowledgement annotieren den kanonischen M1-Zustand; externe Mail/SMS-Zustellung und eine vollständige Eskalationsengine gehören nicht zum Umfang.
- Historische Unix-, alte Perl-, CFEngine- und Produktkompatibilität bleibt ohne gesonderten Nachweis unverifiziert.

## Zukünftige Erweiterungen

- Eingeschränkte Live-SSH-Abnahme in einer Wegwerf-VM, Schlüsselrotation und Recovery-Übung für kompromittierte Schlüssel.
- Optionale Benachrichtigungszustellung, Alert-Throttling über die Zustandswechsel-Deduplizierung hinaus und erweiterte Diagnose.
- Historische MRTG-/RRDtool-/CFEngine- und originale Unix-Gasttests.
- Nagios/Ganglia, SNMP-Polling, Provisioning und automatische Reparatur.

## Abnahmenachweise

- GitHub-Actions-Lauf `45392269226` bestand `make test`; im Log stehen `M2.1 SSH integration: PASS sshd=/usr/sbin/sshd` und `documents=52 missing=0 broken_links=0`.
- Die native M3-Abnahme bestand mit den unter `/tmp` ausgepackten Debian-Paketen MRTG 2.17.10 und RRDtool 1.7.2; HTML-, PNG- und RRD-Fetch-Artefakte wurden erzeugt und geprüft.
- M4 Backup/Restore, Maintenance/Acknowledgement, beide Beispiel-Labore und die saubere Release-Extraktion bestanden lokal.
- Das Release-Paket erzeugte Quellarchiv, Manifest und SHA256-Checksum-Manifest ohne Laufzeitdaten oder private Schlüssel.

## Befehle für das Release-Gate

    make test
    examples/monitoring-lab.sh
    examples/m2-enrollment-lab.sh
    tests/m3-native.sh --require
    tests/m4-backup.sh
    tests/m4-operations.sh
    tests/m2-ssh-integration.sh --require

Zusätzlich sind saubere Extraktion, Checksum-Manifeste, synchrones `main`/`origin/main`, erfolgreiche Actions für den exakten Commit und ein geprüfter annotierter Tag erforderlich. Diese Vorveröffentlichungsprüfungen sind für `7920cad` abgeschlossen; die Veröffentlichung muss noch exakt auf diesen geprüften Commit zeigen.
