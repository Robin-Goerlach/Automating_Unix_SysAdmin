# CFEngine-1-Konfigurationskandidat

English: [English version](README.md)

Das Kompatibilitätsprofil 1999 verwendet **CFEngine 1**, nicht die spätere CFEngine-2-Konfiguration aus dem Referenzbuch von 2009. Dieses Verzeichnis enthält ein kleines, eigenständig geschriebenes, lesendes Konfigurationsbeispiel zur Prüfung von Dateimetadaten ohne Änderungen.

`cfagent.conf` ist absichtlich klein. Es benennt eine harmlose Markerdatei unter `/tmp` und fordert eine Warnung statt einer Korrektur an. Der Kandidat folgt der dokumentierten Form mit `control`, `actionsequence`, `files`, `any::`, `mode` und `action=warn`. Es wird **nicht** behauptet, dass CFEngine 1.4.0 die Datei geparst oder ausgeführt hat: Während dieses Arbeitsschritts stand weder ein originales Programm noch ein passendes historisches Betriebssystem zur Verfügung.

Der gleiche Kandidat liegt unter `policies/lab-marker.conf`; `examples/role-selection.txt` beschreibt die Grenze zwischen SASD-Rollenlabels und nativen CFEngine-Klassen.

Der GNU-Archivindex bestätigt ein Archiv `cfengine-1.4.0.tar.gz` vom 12.06.1997 und ein Archiv 1.5.0 vom 18.06.1999. Öffentliche historische Referenzen bestätigen `cfagent`/`cfagent.conf`, `-f`, `-v`, `-n`, `actionsequence` sowie die Begriffe `classes`/`groups`; dies ist jedoch keine native Abnahmeevidenz. Siehe `docs/PROVENANCE.md`.

SASD-Rollenklassen wie `baseline` und `role_web` sind vom Resolver `bin/sasd-site-classes` ausgegebene Auswahllabels. Sie werden nicht als native CFEngine-Klassen behauptet, solange kein passendes Programm getestet wurde.

Die Datei darf nicht automatisch nach `/etc/cfengine` installiert werden. Einen historischen Daemon nicht als root ausführen und sein Kontrollsocket nicht an ein echtes Netz öffnen. Für unbeaufsichtigte Abweichungsprüfungen ohne externe Abhängigkeit dient `bin/sasd-config-drift`.

CFEngine-2-Policies späterer Profile gehören nach erfolgreicher Prüfung von Parser und Originalbefehlen getrennt unter `cfengine/v2`. Moderne CFEngine-3-Syntax darf nicht stillschweigend als Ersatz verwendet werden.
