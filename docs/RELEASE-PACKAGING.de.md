# Release-Paketierung

English: [English version](RELEASE-PACKAGING.md)

`release/package.sh` erzeugt aus einem ausdrücklich aufgelösten Git-Commit ein versionsbezogenes Quellarchiv. Es schreibt nur in das mit `--out` angegebene absolute Verzeichnis und verweigert vorhandene Artefakte. Archiv, Dateimanifest und SHA256-Nachweise dokumentieren den tatsächlichen Quell-Commit; gzip-Zeitstempel werden für reproduzierbare Ausgaben unterdrückt.

Beispiel:

    release/package.sh --version 1.1.0-dev --ref HEAD --out /tmp/sasd-release --test

`--test` prüft saubere Extraktion, LF-/Executable-Eigenschaften und die Offline-Tests M5–M7. Für die Reproduzierbarkeit wird zweimal in getrennte leere Verzeichnisse paketiert und anschließend werden die Archive verglichen. Dies ist ein unveröffentlichter lokaler Kandidat; es wird kein Tag und kein GitHub-Release erzeugt. `release/package-1.0.sh` bleibt der unveränderte historische V1.0-Paketierungspfad.

Das Paket ist keine native Plattform- oder Netzwerkinstallationsabnahme. Fehlendes KVM, DHCP/TFTP, historische Unix-Systeme und externe Monitoringprogramme bleiben getrennte `SKIPPED`-/`NOT TESTED`-Gates.
