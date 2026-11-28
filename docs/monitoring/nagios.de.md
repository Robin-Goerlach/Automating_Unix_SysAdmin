# Nagios-Kandidatenintegration

English: [English version](nagios.md)

Nagios ist ein späteres Produktprofil und vom NetSaint-Kandidaten für 1999 getrennt. Als Forschungsziel ist das bei SourceForge aufgeführte Release-Artefakt `nagios-1.0a7` mit Zeitstempel 13. März 2002 ausgewählt. Die offizielle Nagios-Historie belegt die Umbenennung von NetSaint im Jahr 2002; der Archiveintrag beweist nicht, dass jede erzeugte Direktive von diesem Binärprogramm akzeptiert wird.

`bin/sasd-config-nagios` liest Rechner, Rollen, Checks, Dienste und Lebenszyklus aus dem gemeinsamen Inventar. Aktive Rechner werden als Host-, Hostgruppen- und Serviceobjekte ausgegeben; deaktivierte und entfernte Rechner fehlen. Der begrenzte Kandidat enthält Zeitperiode, Kommando, Kontakt, Kontaktgruppe und Servicegruppe sowie aktive/passive Checks und Benachrichtigungen. Nagios wird nicht gestartet, keine Datei installiert und kein Produktivpfad verändert.

Der Kommandovertrag ist ausdrücklich:

    $USER1$/sasd-check-plugin --plugin $USER1$/sasd-check-adapter --check sasd --arg $ARG1$ --arg $HOSTNAME$ --arg $ARG2$

Die Objektargumente geben den Inventar-Check und das Quellargument an.
`$HOSTNAME$` bezeichnet das Ziel. `$USER1$` muss auf ein vertrauenswürdiges
Plugin-Verzeichnis zeigen, dessen absoluter Pfad nur Buchstaben, Ziffern,
Unterstriche, Bindestriche, Punkte und Schrägstriche enthält. Der Generator
wendet dieselbe Einschränkung auf Fixture-Pfade an und weist Traversierung ab.

Hostobjekte verwenden `conn!-` für die Erreichbarkeit. Dienstobjekte behalten
ihren Inventar-Check, etwa `http!-` für die Webdienstverfügbarkeit und
`disk!-` für die Dateisystembelegung. `-` kennzeichnet eine fehlende
Messquelle. Alle drei Beispiele liefern UNKNOWN (Exit 3). Für ein Labor
`--disk-fixture DATEI --fixture-host HOST` zusammen angeben. Nur der
Disk-Dienst des gewählten aktiven Rechners verwendet diese Datei. Das Ergebnis
trägt `source=FIXTURE`. Der gemeinsame Adapter kann eine lokal erfasste
Datei mit `--offline disk HOST DATEI` lesen und kennzeichnet das Ergebnis
als `source=OFFLINE`. Tatsächliche Dateisysteme entfernter Rechner benötigen
eine separat abgenommene Messquelle. Ein `LIVE`-Messpfad bleibt offen.

Der gemeinsame Runner reicht ausschließlich ausdrücklich mit `--arg`
übergebene Werte weiter. Der Adapter prüft Ziel, Eingabe und Beobachtungen
und ordnet OK/WARNING/CRITICAL/UNKNOWN die Exit-Codes 0/1/2/3 zu. Für
erfasste POSIX-`df -kP`-Ausgaben werden Spalten der C-Locale und
Mountpfade ohne Leerraum erwartet. Leere, fehlende und fehlerhafte Ausgaben
sowie reine Kopfzeilen ergeben UNKNOWN. Der höchste Schweregrad bestimmt
Exit-Code und Meldung. UNKNOWN hat Vorrang vor CRITICAL. Die Offline-Regression
löst die Makros auf und führt den erzeugten Argumentvektor direkt aus.

`bin/sasd-status-import-nagios` akzeptiert ausschließlich SASDs synthetisches Zeilenformat, etwa `status web.lab.invalid.http red (1700000000) message`. Es prüft Lebenszyklus und Rolle, weist Duplikate und begrenzte fehlerhafte Eingaben zurück und erzeugt SASD-Datensätze. Es parst kein natives `status.dat`, erzeugt keine authentifizierte Clientidentität und akzeptiert keinen Socket.

Geprüfte historische Quellen:

- [Nagios-Historie](https://www.nagios.org/about/history/) für den NetSaint-Ursprung 1999 und die Umbenennung 2002.
- [SourceForge-Altreleases](https://sourceforge.net/projects/nagios/files/OldFiles/) für `nagios-1.0a7.tar.gz` vom 13. März 2002.
- [Nagios-Objektdefinitionen](https://assets.nagios.com/downloads/nagioscore/docs/nagioscore/3/en/objectdefinitions.html) für das langfristige Objektvokabular und das Plugin-Kommandomodell; dies wird nicht als exakte Parserdokumentation für 1.0a7 ausgegeben.

Status: Offline-Kandidat, zeitgenössisch regressionsgetestet, native Nagios-Parserabnahme NOT TESTED. SASD startet keinen Nagios-Daemon, Listener oder Benachrichtigungsdienst.
