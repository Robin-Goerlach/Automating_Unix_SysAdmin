# Kontrollierte Konfigurationsbereitstellung

`bin/sasd-config-deploy` ist die erste begrenzte Bereitstellungssteuerung für das gemeinsame Site-Modell. Das Offline-Werkzeug arbeitet unprivilegiert in einem ausdrücklich angegebenen Wegwerfpräfix. Es kontaktiert keine Rechner, startet keine Dienste, installiert keine Pakete und entfernt keine Dateien allein wegen einer fehlenden Inventarzuordnung.

Die Vorbereitung verwendet die vorhandenen Generatoren und staged `site/host-services.tsv`, getrennte Big-Brother-/Big-Sister-Kandidaten sowie CFEngine-1/2-Kandidaten. `MANIFEST.tsv` besitzt die Version `SASD-DEPLOY-1` und speichert relativen Pfad, SHA-256 und Modus. Der Plan speichert Manifest-Prüfsumme und Ziel-Prüfsumme (`MISSING` oder Wert) jeder Zieldatei.

    bin/sasd-config-deploy ... --staging /tmp/sasd-stage --target /tmp/sasd-target --plan /tmp/sasd.plan --prepare
    bin/sasd-config-deploy ... --staging /tmp/sasd-stage --target /tmp/sasd-target --plan /tmp/sasd.plan --dry-run
    bin/sasd-config-deploy ... --staging /tmp/sasd-stage --target /tmp/sasd-target --plan /tmp/sasd.plan --apply

Dry-run prüft Manifest und Plan, ohne Zieldateien, Backups oder eine dauerhafte Sperre zu schreiben. Apply nimmt eine kooperative Sperre, prüft sämtliche Staging-Prüfsummen und den Ziel-Snapshot erneut und ändert nur im Manifest aufgeführte Dateien. Unveränderte Dateien werden nicht neu geschrieben. Vorhandene Dateien werden vor dem Ersetzen in ein privates Backup verschoben; der Test-Hook `--fail-after N` weist Rollback nach einem Teilfehler nach.

Das Manifest weist absolute Pfade, Traversal, Symlinks, nicht-reguläre Dateien und unerwartete zusätzliche Staging-Dateien zurück. Crash-Atomarität, Schutz gegen feindliche TOCTOU-Angriffe und native Kompatibilität mit Big Brother, Big Sister, CFEngine, MRTG oder RRDtool werden nicht behauptet. Big Sister behält die kombinierte Vorschau; `--display-out FILE --network-out FILE` erzeugt getrennte Staging-Dateien.
