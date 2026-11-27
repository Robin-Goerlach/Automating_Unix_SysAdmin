# Offline-Vertikalschnitt für Datenbank-Monitoring

English: [English version](database.md)

Dieses Repository implementiert `db-probe`, `db-health`, `db-activity` oder
`db-storage` nicht erneut. Die wiederverwendbaren Diagnosen gehören zu SASD
Freeware. Dieses Paket ergänzt nur einen begrenzten Orchestrierungsadapter für
eine dokumentierte synthetische `db-health`-Beobachtung.

`site/databases.tsv` ist das Instanzinventar. Jede Zeile nennt Instanz,
Rechner, Datenbankprodukt, erwartete Version, Profil und Lebenszyklus. Ein
Rechner darf daher mehrere Datenbankinstanzen besitzen. Der Rechner-
Lebenszyklus bleibt Eigentum von `site/hosts.tsv` und seiner Zustandsdatei.

`bin/sasd-db-health-adapter` akzeptiert das Schlüssel-/Wert-Fixtureformat
`SASD-DB-HEALTH-1` und erzeugt den gemeinsamen vierfeldrigen SASD-
Statusdatensatz. Es prüft die Instanz-/Rechnerzuordnung, Produkt/Version
(`MariaDB 10.11`, `MySQL 8.x` oder `PostgreSQL 10+` in diesem ersten Schnitt),
aktiven Lebenszyklus, vollständige Sichtbarkeit, Messwerte und Frische. Die
Schwellenwerte für aktive Sitzungen sind ausdrückliche Optionen; aus der Zahl
der Verbindungen allein wird keine Gesundheit abgeleitet. Die Meldung enthält
die nicht fachlichen Messwerte und ausdrücklich `source=OFFLINE`.

Akzeptierte Schwellenwerte liefern green/yellow/red; UNKNOWN-Bedingungen wie
veraltete oder zukünftige Beobachtungen, unbekannte Instanzen, deaktivierte
Rechner, unvollständige Sichtbarkeit, Versionsabweichungen oder fehlerhafte
Messwerte liefern purple. Der Adapter öffnet keine Datenbankverbindung, liest
keine Anwendungsdaten, akzeptiert kein Passwort, führt kein SQL aus und
schreibt keine Datenbank.

Die Fixtures decken gesund, WARNING, CRITICAL, veraltet, unvollständige
Sichtbarkeit, unbekannte Instanz und Versionsabweichung ab. `tests/database.sh`
und `examples/sasd-integrated-site-lab.sh` prüfen den vollständigen Offlineweg.
Dies belegt nur den Adaptervertrag, nicht Datenbankserver, Client-Treiber,
TLS, Authentifizierung oder historische Versionen.
