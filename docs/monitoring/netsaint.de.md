# NetSaint-Kandidat C4

NetSaint ist ein eigenes historisches Produktprofil und keine rückdatierte Nagios-Syntax. Die offizielle Nagios-Historie beschreibt die Open-Source-Veröffentlichung 1999 unter dem Namen NetSaint und die Umbenennung 2002 wegen Markenfragen ([Historie](https://www.nagios.org/about/history/)). Eine zeitgenössische Debian-Diskussion beschreibt GPL-Netzwerküberwachung mit Host-/Service-Prüfungen, Plugins und Webausgabe ([Debian-Archiv](https://lists.debian.org/debian-devel/1999/11/msg00316.html)). Ein späteres FreeBSD-Archiv führt ein NetSaint-0.0.7-Paket ([Paketindex](https://archive.freebsd.org/ports/alpha/packages-4.6-release/All/)). Dies sind Provenienzquellen, keine native Abnahme.

`bin/sasd-config-netsaint` leitet deterministisch eine `hosts.cfg`-Kandidatin aus dem gemeinsamen Inventar ab. Erzeugt werden Host-, Hostgruppen-, Service-, Kommando-, Kontakt-, Kontaktgruppen- und Zeitperiodenobjekte. Deaktivierte und entfernte Hosts werden ausgeschlossen; die vorhandenen sicheren Ausgabeschutzprüfungen gelten weiter. Das Ziel ist ein NetSaint-0.0.7-ähnliches Profil und bleibt `UNVERIFIED`, bis ein benanntes historisches System die Datei einliest.

`bin/sasd-check-plugin` startet genau eine ausgewählte ausführbare Datei ohne Shell, begrenzt Zeit und Ausgabe und ordnet Exit 0/1/2/3 green/yellow/red/purple zu. Unbekannte und technische Fehler werden purple und niemals erfolgreich.

`bin/sasd-status-import-netsaint` akzeptiert nur synthetische Offlinezeilen der Form `status HOST.CHECK COLOR (EPOCH) MESSAGE`. Der gemeinsame Host-Lebenszyklus wird angewendet; Beobachtungen für deaktivierte oder entfernte Hosts werden vor der Prüfung von Identität, Rolle, Farben, Duplikaten und Meldungslänge abgewiesen. Kein natives `status.dat`, keine vorgetäuschte SASD-Identität, kein Socket und kein NetSaint-Start. Die Kandidatin wird unter `netsaint/hosts.cfg` staged; produktive Pfade bleiben unberührt.

Exakte Grammatik, Argumente, Benachrichtigungen, Abhängigkeiten und Parserkompatibilität von 1999 werden nicht behauptet. Nagios bleibt P4, Ganglia P5.
