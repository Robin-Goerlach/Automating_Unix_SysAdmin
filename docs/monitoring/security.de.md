# Sicherheitsgrenzen von M1

English: [English version](security.md)

Der M1-Server arbeitet lokal und unprivilegiert. Es gibt keinen Listener, keinen Remote-Befehl, keinen Paketinstaller, keine Dienstregistrierung und keinen automatischen Reparaturmodus.

Der Installer akzeptiert nur eine freigegebene Repository-Konfiguration, weist Systempräfixe und symbolische Pfadkomponenten zurück, verlangt `--apply` und erhält vorhandene Dateien. Laufzeitdateien werden in privaten Verzeichnissen mit regulären Dateien und begrenzter History geschrieben.

Der Import vertraut nur einer vom Administrator ausgewählten lokalen Eingabe. Er prüft Inventar, Check-Zuordnung, Bezeichner, Farben, Meldung, Quelle und Zeitstempel. Das ist kein sicheres Enrollment. M2 muss Identität, Freigabe, kurzlebige Zugangsdaten, authentifizierten Transport, Widerruf und Schlüsselwechsel ergänzen.

Die HTML-Ausgabe escaped Host, Check, Farbe und Meldung. Risiken durch symbolische Vorfahren und feindliche gleichzeitige Schreiber bleiben Grenzen der lokalen Umgebung; nicht als root in gemeinsam beschreibbaren Verzeichnissen betreiben.
