# SASD-Rechnerinventar und Rollenzuordnung

English: [English version](README.md)

Dieses Verzeichnis enthält ein kleines Rechnerinventar für das Kompatibilitätsprofil 1999. Die Datensätze verwenden reservierte Dokumentationsadressen; die Programme lösen die Namen nicht auf und kontaktieren diese Adressen nicht.

`hosts.tsv` besitzt sechs tabulatorgetrennte Felder:

    hostname  address  os-family  role  groups  profile

Die Adresse muss ein IPv4-Wert sein; das Beispiel verwendet `192.0.2.0/24`. `groups` ist eine kommaseparierte Liste oder leer. `profile` ist `baseline` oder die Rolle des Rechners. `roles.tsv` besitzt vier Felder:

    role  sasd-class  profile  manifest

Das Manifest ist relativ zum ausgewählten Golden-Root und wird von der lesenden Prüfung verwendet. Einen Rechner fügt man durch einen validierten Datensatz mit vorhandener Rolle hinzu; eine neue Rolle benötigt einen Rollendatensatz und ein Manifest.

`services.tsv` ist die versionierte Service-Schicht: Servicename, zuständige Rolle, vorhandener Checkname, Kompatibilitätsprofil und Beschreibung. Prüfung und Auflösung:

    bin/sasd-site-services --hosts site/hosts.tsv --roles site/roles.tsv \
      --checks site/checks.tsv --services site/services.tsv --host web.lab.invalid

Die Ausgabe enthält nur für den Host passende Serviceauswahlen. Das Kommando prüft, startet, stoppt und konfiguriert keinen Dienst. Generatoren und Audits arbeiten mit ausdrücklich angegebenen Dateien und behalten ihre eigenen Sicherheitsgrenzen.

Vor der Verwendung `bin/sasd-site-inventory --check` ausführen. `bin/sasd-site-classes` gibt Rechner, unabhängige SASD-Klassen, Rolle, Profil, Klasse und Manifest aus. Die Klassen dienen nur der Auswahl und ersetzen nicht die native CFEngine-Klassenlogik.

Die Prüfung delegiert den Bytevergleich an `bin/sasd-config-drift`:

    bin/sasd-site-audit --input site/hosts.tsv --roles site/roles.tsv \
      --host web.lab.invalid --root fixtures/site/actual \
      --golden fixtures/site/golden --status

Der abschließende Statusdatensatz kann bei Bedarf an `sasd-status-store` übergeben werden. Diese Befehle kopieren keine Dateien, ändern keine Modi, lösen kein DNS auf und schreiben nicht nach `/etc`.
