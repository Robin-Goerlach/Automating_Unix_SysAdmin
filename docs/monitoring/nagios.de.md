# Nagios-Kandidatenintegration

English: [English version](nagios.md)

Nagios ist ein späteres Produktprofil und vom NetSaint-Kandidaten für 1999 getrennt. Als Forschungsziel ist das bei SourceForge aufgeführte Release-Artefakt `nagios-1.0a7` mit Zeitstempel 13. März 2002 ausgewählt. Die offizielle Nagios-Historie belegt die Umbenennung von NetSaint im Jahr 2002; der Archiveintrag beweist nicht, dass jede erzeugte Direktive von diesem Binärprogramm akzeptiert wird.

`bin/sasd-config-nagios` liest Rechner, Rollen, Checks, Dienste und Lebenszyklus aus dem gemeinsamen Inventar. Aktive Rechner werden als Host-, Hostgruppen- und Serviceobjekte ausgegeben; deaktivierte und entfernte Rechner fehlen. Der begrenzte Kandidat enthält Zeitperiode, Kommando, Kontakt, Kontaktgruppe und Servicegruppe sowie aktive/passive Checks und Benachrichtigungen. Nagios wird nicht gestartet, keine Datei installiert und kein Produktivpfad verändert.

Der Kommandovertrag ist ausdrücklich:

    $USER1$/sasd-check-plugin --plugin $USER1$/sasd-check-adapter --check sasd --arg $ARG1$ --arg $HOSTNAME$ --arg $ARG2$

`sasd-check-adapter` ordnet derzeit nur `disk` dem vorhandenen Programm `sasd-disk-watch` und einer ausdrücklich kontrollierten Eingabedatei zu. Andere Checks liefern UNKNOWN/NOT IMPLEMENTED. Der Zielhostname ist eine Identitätsangabe und die Fixture ein ausdrückliches Argument; der Offline-Adapter behauptet keine Prüfung eines entfernten Rechners und prüft nicht stillschweigend den Monitoringserver an seiner Stelle. Für echte entfernte Prüfungen ist ein separat abgenommener Agent oder natives Nagios-Plugin erforderlich.

`bin/sasd-status-import-nagios` akzeptiert ausschließlich SASDs synthetisches Zeilenformat, etwa `status web.lab.invalid.http red (1700000000) message`. Es prüft Lebenszyklus und Rolle, weist Duplikate und begrenzte fehlerhafte Eingaben zurück und erzeugt SASD-Datensätze. Es parst kein natives `status.dat`, erzeugt keine authentifizierte Clientidentität und akzeptiert keinen Socket.

Geprüfte historische Quellen:

- [Nagios-Historie](https://www.nagios.org/about/history/) für den NetSaint-Ursprung 1999 und die Umbenennung 2002.
- [SourceForge-Altreleases](https://sourceforge.net/projects/nagios/files/OldFiles/) für `nagios-1.0a7.tar.gz` vom 13. März 2002.
- [Nagios-Objektdefinitionen](https://assets.nagios.com/downloads/nagioscore/docs/nagioscore/3/en/objectdefinitions.html) für das langfristige Objektvokabular und das Plugin-Kommandomodell; dies wird nicht als exakte Parserdokumentation für 1.0a7 ausgegeben.

Status: Offline-Kandidat, zeitgenössisch regressionsgetestet, native Nagios-Parserabnahme NOT TESTED. SASD startet keinen Nagios-Daemon, Listener oder Benachrichtigungsdienst.
