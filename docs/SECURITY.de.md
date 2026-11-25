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

M1 besitzt keinen Listener und kein remote Enrollment. Der Installer verlangt `--apply`, weist Systempräfixe und symbolische Pfadkomponenten zurück, erhält vorhandene Dateien und schreibt nur in ein ausdrückliches Präfix. Der Import vertraut nur einer lokal ausgewählten Eingabedatei; er ist kein authentifizierter Transport. M2 speichert einen SSH-Public-Key-Fingerprint und verlangt ausdrückliche Betreiberfreigabe; Hostname und Inventar sind allein keine Identität.

Signierte M2-Dateien verwenden `ssh-keygen -Y sign/verify`. Vor dem Schreiben prüft der Import Schlüssel, Rollen-/Check-Zuordnung, Ablauf, Zeitfenster und steigende Sequenz. Abgelehnte und gesperrte Datensätze dürfen nicht importieren; Sequenzen bleiben über die Wiederaufnahme erhalten. M2 bietet keinen Live-Transport. Vor einem Netzwerkbetrieb sind Host-Key-Policy, SSH-Kontobeschränkungen, Schlüsselwechsel, Recovery kompromittierter Schlüssel, Zeitvertrauen und Schutz gegen feindliche Mehrfachschreiber zusätzlich abzunehmen.

M5-Archive sind Dateisystemarchive und keine bootfähigen Images. Eine Live-Quelle kann inkonsistent sein; der Betreiber muss sie anhalten oder einen konsistenten Snapshot auswählen. Host-Personalisierung und Identitätserzeugung bleiben absichtlich von der Archivwiederherstellung getrennt. Capture und Restore arbeiten niemals auf Blockgeräten.

Golden-Client-Capture erzeugt Archiv, Manifest und Prüfsummendatei mit Modus `0600`, weist Symlinks, Hardlinks und Spezialdateien im erzeugten Archiv zurück und verwendet ein privates temporäres Verzeichnis. Das schützt Artefakte vor gewöhnlichem Lesen durch Gruppe und andere; Eigentümer, Verschlüsselung und sichere Löschung bleiben Betreiberverantwortung.

M7-Postinstallation verlangt ein ausdrückliches Präfix und einen Imagekatalog, erzeugt über den bestehenden Client-Installer eine neue Identität und erstellt nur einen offenen Antrag. Eine Monitoring-Freigabe wird nie erteilt. Aktive oder gesperrte Server-Registrierungen blockieren eine stille Reinstallation; Schlüsselwechsel und Recovery kompromittierter Schlüssel werden in diesem Meilenstein nicht automatisiert.
