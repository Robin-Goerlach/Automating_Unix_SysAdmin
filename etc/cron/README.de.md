# Hinweise zum geplanten Betrieb

English: [English version](README.md)

Die unterstützte Unix-Anordnung verwendet Cron statt eines dauerhaft laufenden Python- oder Node-Monitoringdienstes.

Ein Administrator kann unabhängige Sammler später im Abstand von fünf Minuten ausführen und eine statische Übersicht neu erzeugen. Cron-Einträge müssen absolute Pfade, unprivilegierte Dienstkonten, einen privaten Spool und keine geerbten Geheimnisse verwenden. Ein automatischer Installer für System-Crontabs existiert derzeit nicht.

Vor jeder Zeitplanung sind Laufzeit des Sammlers, Fehlerberichterstattung, Verzögerung und Jitter, Stale-Behandlung, Sperren und Aufbewahrung zu prüfen. Mehrere Statusschreiber können eine übergeordnete Sperre und atomare Stapelverarbeitung benötigen; diese Tests sind noch nicht vollständig.

Eine Beispiel-Cronzeile nicht ohne diese Prüfungen in die Produktion übernehmen.
