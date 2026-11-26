# SASD-Rechnerinventar und Rollenzuordnung

English: [English version](README.md)

Dieses Verzeichnis enthält ein kleines Rechnerinventar für das Kompatibilitätsprofil 1999. Die Datensätze verwenden reservierte Dokumentationsadressen; die Programme lösen die Namen nicht auf und kontaktieren diese Adressen nicht.

`hosts.tsv` besitzt sechs tabulatorgetrennte Felder:

    hostname  address  os-family  role  groups  profile

Vor dem Datenbereich kann `# SASD-SITE-INVENTORY-1` stehen. Das ist die
explizite aktuelle Formatversion. Unmarkierte bestehende Dateien bleiben als
Legacy-Daten lesbar. Mit `bin/sasd-site-migrate --input site/hosts.tsv
--dry-run` lässt sich die Migration prüfen; `--apply` legt eine
`.pre-versioned`-Sicherung an und ergänzt den Marker. Die Zeilen bleiben
unverändert, Kollisionen werden abgewiesen und eine Wiederholung meldet
`ALREADY-MIGRATED`.

Die Adresse muss ein IPv4-Wert sein; das Beispiel verwendet `192.0.2.0/24`. `groups` ist eine kommaseparierte Liste oder leer. `profile` ist `baseline` oder die Rolle des Rechners. `roles.tsv` besitzt vier Felder:

    role  sasd-class  profile  manifest

Das Manifest ist relativ zum ausgewählten Golden-Root und wird von der lesenden Prüfung verwendet. Einen Rechner fügt man durch einen validierten Datensatz mit vorhandener Rolle hinzu; eine neue Rolle benötigt einen Rollendatensatz und ein Manifest.

`services.tsv` ist die versionierte Service-Schicht: Servicename, zuständige Rolle, vorhandener Checkname, Kompatibilitätsprofil und Beschreibung. Prüfung und Auflösung:

    bin/sasd-site-services --hosts site/hosts.tsv --roles site/roles.tsv \
      --checks site/checks.tsv --services site/services.tsv --host web.lab.invalid

Die Ausgabe enthält nur für den Host passende Serviceauswahlen. Das Kommando prüft, startet, stoppt und konfiguriert keinen Dienst. Generatoren und Audits arbeiten mit ausdrücklich angegebenen Dateien und behalten ihre eigenen Sicherheitsgrenzen.

`bin/sasd-host-admin` ist der begrenzte Inventar-Editor von B. `validate`, `list`, `show` und `reconcile` sind lesend; `add`, `update`, `enable`, `disable` und `remove` benötigen `--apply`. Eine benachbarte Zustandsdatei hält die aktuelle Projektion enabled/disabled/removed fest; eine benachbarte `*.history.tsv`-Datei bewahrt die Lebenszyklusereignisse. `update` erhält einen deaktivierten Zustand; `enable` akzeptiert nur disabled, `disable` nur enabled, und ein entfernter Rechner muss ausdrücklich erneut hinzugefügt werden.

Die Historienfelder sind `epoch`, `hostname`, `operation`, `from-state`, `to-state` und `reason`. Die Datei gehört dem Betreiber, hat Modus `0600`, wird vor jedem Schreiben geprüft und durch denselben Lock wie das Inventar geschützt. Sie bewahrt logische Lebenszyklusereignisse auf, wird bei jeder Änderung aber vollständig neu geschrieben: Sie ist weder append-only noch manipulationssicheres Audit-Storage. Inventar, Zustand und Historie werden gemeinsam vorbereitet und mit Best-Effort-Rollback installiert; ein Absturz zwischen Renames kann weiterhin eine gemischte Generation hinterlassen. Dann ist eine Wiederherstellung aus dem letzten konsistenten Satz oder eine Betreiberprüfung erforderlich.

`bin/sasd-site-config` liest die vier Inventarschichten und erzeugt deterministische `host-services.tsv`- und `manifest.tsv`-Dateien in einem neuen Staging-Verzeichnis. Deaktivierte oder entfernte Hosts aus der benachbarten Zustandsdatei werden ausgelassen. `--check` ist lesend; `--apply` erzeugt nur das ausgewählte Staging-Verzeichnis und verteilt keine native Produktkonfiguration.

Alle fünf Site- und Produktadapter verwenden `SASD::Monitor::read_host_state`. Der Parser weist doppelte Datensätze, Steuerzeichen, ungültige Zustände, unbekannte nicht entfernte Hosts, direkte Symlinks und ausdrücklich fehlende Zustandsdateien zurück. Die standardmäßige benachbarte Zustandsdatei darf fehlen und bedeutet dann, dass Inventarhosts aktiviert sind; mit `--state` wird das Fehlen zum Fehler.

`bin/sasd-site-consistency` ist eine lesende Querverbindung zwischen aktiver Host-/Service-Auswahl und `site/monitoring.conf`. Es prüft, dass das Monitoringmodell dieselben Inventarschichten nennt, jeder aktive Host mindestens einen passenden Dienst erhält und Dienstprofile zum Monitoringprofil passen. Es gibt ausgewählte Host-, Dienst-, Check- und Profilzeilen sowie eine Zusammenfassung aus; Rechner werden nicht kontaktiert und native Produktkonfigurationen nicht geparst.

Das vorhandene `bin/sasd-monitor-mrtg` ist der erste Produktadapter für diese Lebenszyklusprojektion. Mit `--host-state site/hosts.tsv.state` (Standard bei fehlender Option) werden deaktivierte und entfernte Rechner aus der prüfbaren MRTG-Kandidatenkonfiguration ausgelassen. Die Ausgabe bleibt bis zu einem Lauf mit der passenden MRTG-Version eine unbestätigte Vorlage.

Vor der Verwendung `bin/sasd-site-inventory --check` ausführen. `bin/sasd-site-classes` gibt Rechner, unabhängige SASD-Klassen, Rolle, Profil, Klasse und Manifest aus. Die Klassen dienen nur der Auswahl und ersetzen nicht die native CFEngine-Klassenlogik.

Die Prüfung delegiert den Bytevergleich an `bin/sasd-config-drift`:

    bin/sasd-site-audit --input site/hosts.tsv --roles site/roles.tsv \
      --host web.lab.invalid --root fixtures/site/actual \
      --golden fixtures/site/golden --status

Der abschließende Statusdatensatz kann bei Bedarf an `sasd-status-store` übergeben werden. Diese Befehle kopieren keine Dateien, ändern keine Modi, lösen kein DNS auf und schreiben nicht nach `/etc`.
