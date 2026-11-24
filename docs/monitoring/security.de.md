# Sicherheitsgrenzen von M1

English: [English version](security.md)

Der M1/M2-Server arbeitet lokal und unprivilegiert. Es gibt keinen Listener, keinen Remote-Befehl, keinen Paketinstaller, keine Dienstregistrierung und keinen automatischen Reparaturmodus. M2 ist ein Offline-Dateiaustausch mit genehmigtem SSH-Public-Key.

Der Installer akzeptiert nur eine freigegebene Repository-Konfiguration, weist Systempräfixe und symbolische Pfadkomponenten zurück, verlangt `--apply` und erhält vorhandene Dateien. Laufzeitdateien werden in privaten Verzeichnissen mit regulären Dateien und begrenzter History geschrieben.

Der Import vertraut nur einer vom Administrator ausgewählten lokalen Eingabe und prüft Inventar, Check-Zuordnung, Bezeichner, Farben, Meldung, Quelle und Zeitstempel. M2 ergänzt für den Offline-Austausch Identität, Betreiberfreigabe, Signatur, Ablauf, Replay-Schutz und Sperr-/Wiederaufnahme-Lifecycle. M2.1 ergänzt einen SSH-Adapter mit festem Befehl, benötigt aber ein administrativ eingerichtetes eingeschränktes Konto, eine eigene `known_hosts`-Datei und eine native OpenSSH-Abnahme. Die SSH-Daemon-Konfiguration wird nicht selbst geändert.

Die HTML-Ausgabe escaped Host, Check, Farbe und Meldung. Risiken durch symbolische Vorfahren und feindliche gleichzeitige Schreiber bleiben Grenzen der lokalen Umgebung; nicht als root in gemeinsam beschreibbaren Verzeichnissen betreiben.
