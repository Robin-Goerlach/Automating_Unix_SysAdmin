# Kontrollierte Konfigurationsbereitstellung

`bin/sasd-config-deploy` ist die erste begrenzte Bereitstellungssteuerung für das gemeinsame Site-Modell. Das Offline-Werkzeug arbeitet unprivilegiert in einem ausdrücklich angegebenen Wegwerfpräfix. Es kontaktiert keine Rechner, startet keine Dienste, installiert keine Pakete und entfernt keine Dateien allein wegen einer fehlenden Inventarzuordnung.

Die Vorbereitung verwendet die vorhandenen Generatoren und staged `site/host-services.tsv`, getrennte Big-Brother-/Big-Sister-Kandidaten sowie CFEngine-1/2-Kandidaten. `MANIFEST.tsv` besitzt die Version `SASD-DEPLOY-1` und speichert relativen Pfad, SHA-256 und Modus. Der Plan speichert Manifest-Prüfsumme und Ziel-Prüfsumme (`MISSING` oder Wert) jeder Zieldatei.

    mkdir -m 0700 /tmp/sasd-target
    bin/sasd-config-deploy ... --staging /tmp/sasd-stage --target /tmp/sasd-target --plan /tmp/sasd.plan --prepare
    bin/sasd-config-deploy ... --staging /tmp/sasd-stage --target /tmp/sasd-target --plan /tmp/sasd.plan --dry-run
    bin/sasd-config-deploy ... --staging /tmp/sasd-stage --target /tmp/sasd-target --plan /tmp/sasd.plan --apply

Dry-run prüft Manifest und Plan, ohne Zielverzeichnis, Sperre, Backup, temporäre Datei oder veröffentlichte Konfiguration anzulegen. Apply benötigt ein vorhandenes, dem Operator gehörendes Wegwerfverzeichnis unter `/tmp` oder `/var/tmp`; alle relevanten Vorfahren werden auf Symlinks, Eigentümer und Rechte geprüft. Die kooperative Sperre besitzt eine stabile Identität und bleibt nach dem Abschluss erhalten. Apply prüft sämtliche Staging-Prüfsummen und den Ziel-Snapshot erneut, während die Sperre gehalten wird.

Jede geänderte Datei wird in einer exklusiven temporären Datei im Zielverzeichnis geschrieben, auf vollständiges Schreiben, Schließen, Modus und SHA-256 geprüft und anschließend mit `rename` veröffentlicht. Das ist atomar für eine einzelne Datei, aber keine crash-atomare Mehrdatei-Transaktion. Vorhandene Dateien werden vor dem Ersetzen in ein privates Laufzeit-Backup verschoben. Ein kontrollierter Fehler stellt Inhalt und Modus wieder her; scheitert auch das Rollback, bleibt das Backup erhalten und wird gemeldet. Der Test-Hook `--fail-after N` prüft diesen Vertrag.

Manifest und Plan weisen unbekannte oder doppelte Felder, leere Manifeste, doppelte Zielpfade, unsichere Modi, absolute Pfade, Traversal, Symlinks, nicht-reguläre Dateien und unerwartete zusätzliche Staging-Dateien zurück. Der Plan ist ein Integritäts-Snapshot, keine Authentizitätssignatur: SHA-256 erkennt Änderungen innerhalb der dokumentierten Vertrauensgrenze, beweist aber nicht, wer einen manipulierten Plan genehmigt hat. Crash-Atomarität, Schutz gegen feindliche TOCTOU-Angriffe und native Produktkompatibilität werden nicht behauptet. Big Sister behält die kombinierte Vorschau; `--display-out FILE --network-out FILE` erzeugt getrennte Staging-Dateien nach gemeinsamer Zielprüfung.
