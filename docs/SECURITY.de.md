# Sicherheitsregeln für SASD-Unix-Administration

English: [English version](SECURITY.md)

Kompatibilität mit älterer Unix-Software ist keine Sicherheitsausnahme. Optionale Protokolle und Daemons können unsicher sein, wenn sie in aktuelle Netze gestellt werden.

## Sicherer Standardbetrieb

- Wegwerf-Gast mit Host-only/offline-Netz verwenden, nicht Firmen-, Cloud- oder Produktionsnetz.
- Tests unprivilegiert ausführen; kein sudo für die Test-Suite.
- Zuerst synthetische Fixtures verwenden und keine echten `/etc/passwd`- oder `/etc/shadow`-Daten übernehmen.
- Keine Konten, Dienste, Firewalls, Pakete oder Listener durch die erste Implementierung ändern.
- Keine Standard-SNMP-Communities, Klartext-SSH-Geheimnisse oder schwache Schlüssel veröffentlichen.

## Daten und Ausgaben

- Pfadtraversierung, symbolische Ziele, Steuerzeichen und unsichere Statusbezeichner zurückweisen.
- Inventar auf doppelte Rechner, Adressen, ungültige IPv4-Werte und unbekannte Rollen prüfen.
- Privaten Statusspool und private Laufzeitverzeichnisse verwenden.
- HTML-Ausgaben als untrusted behandeln, bis Escaping geprüft wurde.
- Historie nur nach dokumentierter Aufbewahrungsregel begrenzen.
- Driftmeldungen sind keine Berechtigung zur Reparatur.

## M1-Grenze

M1 besitzt keinen Listener und kein remote Enrollment. Der Installer verlangt `--apply`, weist Systempräfixe und symbolische Pfadkomponenten zurück, erhält vorhandene Dateien und schreibt nur in ein ausdrückliches Präfix. Der Import vertraut nur einer lokal ausgewählten Eingabedatei; er ist kein authentifizierter Transport.

Die Laufzeitprüfung bietet kein Rollback und kein Protokoll für feindliche Mehrfachschreiber. M2 muss Rechneridentität, Betreiberfreigabe, kurzlebige Zugangsdaten, authentifizierte Meldungen, Widerruf und Schlüsselwechsel ergänzen.
