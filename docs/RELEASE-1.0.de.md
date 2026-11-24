# SASD-1.0-Umfang und Abnahme

English: [English version](RELEASE-1.0.md)

Status: Releasearbeit läuft. Ein `v1.0.0`-Tag ist erst zulässig, wenn jedes Pflichtgate belegt ist.

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

- Der Live-SSH-Transport ist implementiert, benötigt aber noch einen echten eingeschränkten OpenSSH-Server, geprüften Hostschlüssel-Bootstrap sowie einen erfolgreichen und einen abgelehnten Transfer. Das ausgepackte OpenSSH-9.2-`sshd` konnte im unprivilegierten WSL-Sandbox-Test keinen Socket binden (`Operation not permitted`).
- Die native M3-Evidenz verwendet Debian-Paketversionen 2.17.10 und 1.7.2, die unter `/tmp` ausgepackt wurden. Das ist kein Nachweis historischer Kompatibilität und pollt keine Produktionsschnittstelle.
- Maintenance und Acknowledgement annotieren den kanonischen M1-Zustand; externe Mail/SMS-Zustellung und eine vollständige Eskalationsengine gehören nicht zum Umfang.
- Historische Unix-, alte Perl-, CFEngine- und Produktkompatibilität bleibt ohne gesonderten Nachweis unverifiziert.

## Zukünftige Erweiterungen

- Eingeschränkte Live-SSH-Abnahme in einer Wegwerf-VM, Schlüsselrotation und Recovery-Übung für kompromittierte Schlüssel.
- Optionale Benachrichtigungszustellung, Alert-Throttling über die Zustandswechsel-Deduplizierung hinaus und erweiterte Diagnose.
- Historische MRTG-/RRDtool-/CFEngine- und originale Unix-Gasttests.
- Nagios/Ganglia, SNMP-Polling, Provisioning und automatische Reparatur.

## Befehle für das Release-Gate

    make test
    examples/monitoring-lab.sh
    examples/m2-enrollment-lab.sh
    tests/m3-native.sh --require
    tests/m4-backup.sh
    tests/m4-operations.sh
    tests/m2-ssh-integration.sh --require

Zusätzlich sind saubere Extraktion, Checksum-Manifeste, synchrones `main`/`origin/main`, erfolgreiche Actions für den exakten Commit und ein geprüfter annotierter Tag erforderlich. Solange der SSH-Befehl in einer kontrollierten Umgebung nicht erfolgreich läuft, bleibt das Stable-Release-Gate offen.
