# CFEngine-2-Kandidatenprofil

Dieses Verzeichnis ist ein getrenntes späteres Profil für CFEngine 2. Es verwendet das gemeinsame SASD-Rollen- und Hostinventar sowie den gemeinsamen Lebenszyklusparser; das CFEngine-1-Profil wird nicht wiederverwendet.

`bin/sasd-config-cfengine2` akzeptiert die Versionsprofile `2.0` und `2.1`, erzeugt einen kleinen Kandidaten mit Warnaktionen und lässt deaktivierte oder entfernte Hosts aus. `--dry-run` ist schreibfrei. `--apply` schreibt nur die angeforderte Kandidatendatei mit Modus `0600`; keine Policy wird installiert, kein `cfagent` gestartet, kein Server kontaktiert und kein Host repariert.

Die erzeugten Abschnitte `control`, `classes` und `files` sind eigenständig entwickelte Prüfkandidaten. Sie sind keine native Abnahmeevidenz. In dieser WSL-Arbeit stand kein passendes CFEngine-2-Programm, Betriebssystem, Parserausgabe oder Diensteinsatz zur Verfügung. CFEngine-3-Syntax darf nicht stillschweigend als Ersatz verwendet werden.
