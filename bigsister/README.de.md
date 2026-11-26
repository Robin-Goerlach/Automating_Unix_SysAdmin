# Big-Sister-Kandidatintegration

English: [English version](README.md)

Big Sister wird als eigenständiges historisches Produkt behandelt. Die öffentliche Dokumentation beschreibt `adm/bb-display.cfg` als Konfiguration des Status-Collectors mit Prozent-Direktiven und `adm/uxmon-net` als Datei für Rechner-/Prüfregeln. Der Generator übernimmt daher nicht die Big-Brother-Syntax von `bb-hosts`.

`bin/sasd-config-bigsister` liest Hosts, Rollen, Checks, Dienste und Lebenszykluszustand aus dem gemeinsamen Modell und erzeugt eine nur zu prüfende Kandidatenausgabe für diese beiden Schnittstellen. Deaktivierte und entfernte Rechner werden ausgelassen. `--out` schützt Eingaben; das Ersetzen einer vorhandenen Datei erfordert `--force`.

`bin/sasd-status-import-bigsister` akzeptiert begrenzte synthetische Zeilen `status host.check color comment` und gibt SASDs vierfeldriges Beobachtungsformat aus. Rechner-/Check-Zuordnung, Farben, Nachrichtenlänge und doppelte Beobachtungen werden geprüft. Es öffnet keinen Socket und behauptet keine native Protokollkompatibilität.

Das erste Profil ist mit `2000` gekennzeichnet, weil die öffentliche Änderungshistorie Big-Sister-Konfiguration und Status-Collector-Arbeiten im Jahr 2000 dokumentiert. Die Projektseite nennt 0.99/0.99c3 und freie Software; die Lizenz bleibt extern. Big-Sister-Quelltext, Daemons und Lizenztexte werden nicht weitergegeben.

Quellen: https://www.bigsister.ch/bigsister.html, https://www.bigsister.ch/pdoc/CONFIG.html, https://www.bigsister.ch/pdoc/CHANGES.html und https://fossies.org/linux/big-sister/.

Es gibt nur Offline-Fixture-Tests. Ein Parserlauf mit genau benannter Big-Sister-Version auf historischem Unix bleibt offen.
