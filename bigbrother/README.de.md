# Big-Brother-Hostinventarformat ohne Reproduktion von Big Brother

English: [English version](README.md)

Eine frühe Konvention des Big-Brother-Hostinventars identifizierte Rechner über Adresse/Name und ergänzte Netzwerkprüfungen oder Serverrollen hinter einem `#`-Trennzeichen. Dieses Verzeichnis enthält eine eigenständige Beispielkonfiguration mit TEST-NET-Adressen und `.invalid`-Namen. Es enthält keine Big-Brother-Programme, Quellen, Authentifizierungsdaten, Alarmimplementierung oder Netzwerkpakete.

    ./bin/sasd-bb-hosts-lint --input bigbrother/bb-hosts.example

Der Linter prüft eine kleine ASCII/IPv4-Teilmenge, gibt nur Hostnamen und Adressen aus und baut keine Netzwerkverbindung auf. Das beweist keine Annahme durch eine bestimmte Big-Brother-Version. Eine ordnungsgemäß lizenzierte historische Version muss in einer Wegwerf-Umgebung installiert, die genaue `bb-hosts`-Grammatik anhand der Originaldokumentation geprüft und separat getestet werden, bevor Kompatibilität behauptet wird.

Für einen unabhängigen SASD-Statussammler dienen `bin/sasd-status-store` und `bin/sasd-status-board`; ihr TSV-Format ist nicht das BB-Drahtprotokoll.

`bin/sasd-config-bigbrother` ist ein getrennter Offline-Adapter. Er liest das
gemeinsame SASD-Inventar, die Dienste und den Lebenszykluszustand und erzeugt
eine nur zu prüfende Big-Brother-artige Hostdatei. Deaktivierte und entfernte
Rechner werden ausgelassen. Er führt keine Netzwerkaktion, Installation oder
Dienstaktivierung aus; die Ausgabe ist kein Nachweis einer nativen Abnahme für
eine Big-Brother-Version.

Historischer Hintergrund:

- https://linuxgazette.net/issue15/bb-info.html — Überblick von Ende 1996
- https://linuxgazette.net/issue15/bbartlg.html — Artikel von 1997 zu Konfiguration und Dienstprüfungen
- https://www.linux-magazin.de/ausgaben/2002/09/grosser-bruder/ — spätere Betriebsbesprechung

Produktmarken, Code und Lizenzen sind unabhängig von diesem MIT-lizenzierten SASD-Repository. Originale Big-Brother-Daemons dürfen nicht außerhalb einer isolierten Umgebung exponiert werden.
