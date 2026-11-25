# M7-Postinstallation und Monitoring-Enrollment

English: [English version](postinstall.md)

`bin/sasd-postinstall` verarbeitet ein validiertes M6-Profil und einen M5/M6-Imagekatalog. Es prüft ausgewählte Image-ID, optional erwartete Image-Version und Architektur und delegiert die Clientinstallation anschließend an den bestehenden `install/install-sasd-client.sh`.

Beispiel:

```sh
bin/sasd-postinstall \
  --root /tmp/sasd-client-a \
  --profile-file profiles.tsv --images images.tsv \
  --image-version 1.0 --profile web-lab \
  --host client-a.lab.invalid --expires-at 2000000000 --dry-run
```

`--apply` nur mit einem neuen Wegwerfpräfix verwenden. Das Werkzeug schreibt Hostname, einen kleinen Postinstallationsdatensatz, eine neue SSH-Client-Identität und einen Enrollment-Antrag. Es schreibt nicht in produktives `/etc`, installiert keinen Dienst, aktiviert kein Cron, überträgt den Antrag nicht und genehmigt kein Monitoring. Die vorhandene Installationsgrenze mit ausdrücklichem Apply bleibt bestehen.

Die Monitoring-Übergabe bleibt unverändert:

1. Betreiber importiert den Antrag mit `sasd-enrollment --action import-request`.
2. Betreiber prüft Rechner, Rolle, Profil, Ablauf und Public-Key-Fingerprint.
3. Betreiber genehmigt oder verwirft den Antrag ausdrücklich.
4. Der Node erzeugt signierte Statusdateien mit `sasd-node-status`.
5. Der bestehende M2-/M2.1-Transport und `sasd-monitor-auth-import` prüfen und importieren sie.

## Reinstallation und Identität

Jeder Postinstallationslauf erzeugt eine neue Client-Identität. Das Kopieren eines Clientpräfixes wird abgelehnt, weil Postinstallationsdatensatz und Identität bereits vorhanden sind. Ein neuer Antrag für einen Rechner mit aktivem oder gesperrtem Enrollment-Datensatz wird von der bestehenden Enrollment-Steuerung abgelehnt; ein genehmigter Schlüssel kann nicht stillschweigend ersetzt werden. Schlüsselwechsel und Recovery kompromittierter Schlüssel benötigen ein eigenes Betreiberverfahren und werden nicht als automatisierte M7-Funktion behauptet.

`tests/m7-postinstall.sh` prüft zwei simulierte Rechner, eindeutige Identitäten, Ablehnung veralteter Image-Versionen, geheimnisartige Profilwerte, Clone-Ablehnung, genehmigten Statusimport, abgelehnten Statusimport und die Ablehnung einer Reinstallation eines aktiven Rechners. `examples/m7-install-to-monitoring.sh` demonstriert die Offline-Übergabe.
