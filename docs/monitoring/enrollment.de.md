# M2-Registrierung und Unix-Node-Bootstrap

English: [English version](enrollment.md)

M2 ergänzt den M1-Verzeichnisaufbau um eine begrenzte Registrierungssteuerung. Der Ablauf ist bewusst offline: Ein Client erstellt einen Antrag und eine signierte Statusdatei; ein Betreiber übernimmt diese Dateien in das private Laufzeitverzeichnis des Servers. Es gibt keinen Listener, keine automatische Registrierung, keine Remote-Shell und keine produktive Installation.

## Identität und Lifecycle

Der Client erzeugt mit `ssh-keygen` einen RSA-SSH-Schlüssel. Der SHA-256-Fingerprint des öffentlichen Schlüssels steht im Antrag und wird zur genehmigten Rechneridentität. Hostname, Inventaradresse, Rolle und Betriebssystembezeichnung sind keine kryptografische Authentifizierung.

Unter `var/enrollment/` speichert der Server Anträge und Datensätze:

    requests/HOST.request
    records/HOST.tsv
    events.tsv

Public Key und letzte akzeptierte Sequenz stehen im Host-Datensatz; `replay/` ist ein privater temporärer Prüfbereich.

Der Lifecycle lautet `pending-approval`, `approved`, `active`, `rejected` oder `disabled`. `sasd-enrollment` importiert Anträge, listet und prüft Datensätze, genehmigt, verwirft, sperrt, reaktiviert und zeigt Rechnerstatus. Eine Freigabe aktiviert den Host erst nach einer gültigen signierten Statusdatei.

## Client-Bootstrap

Der Wegwerf-Installer erkennt die von `uname` gemeldeten Namen Linux, FreeBSD, OpenBSD, NetBSD, SunOS, AIX und HP-UX. Er verlangt ein ausdrückliches Nicht-Systempräfix und `--apply` für Schreibvorgänge:

    install/install-sasd-client.sh \
      --prefix /tmp/sasd-node \
      --host node.lab.invalid --role web --profile web \
      --expires-at 2000000000 --apply

Er kopiert nur freigegebene Clientwerkzeuge, erzeugt eine unprivilegierte RSA-Identität, schreibt einen Antrag und legt eine kommentierte Cron-Vorlage an. `/etc` wird nicht beschrieben, kein Paket und kein Dienst installiert oder aktiviert und kein Antrag übertragen.

Der Betreiber prüft den Antrag mit:

    bin/sasd-enrollment --dir PREFIX/var/enrollment \
      --action import-request --request /tmp/sasd-node/var/enrollment.request
    bin/sasd-enrollment --dir PREFIX/var/enrollment \
      --action approve --host node.lab.invalid --operator admin --at 1000

## Authentifizierte Statusdateien

Die bestehenden Vierfeld-Datensätze bleiben erhalten:

    host<TAB>check<TAB>color<TAB>message

`bin/sasd-node-status` ergänzt einen signierten `SASD-AUTH-1`-Kopf mit genehmigtem Host, streng steigender Sequenz und Sendezeit. Die vollständige Datei wird mit `ssh-keygen -Y sign` und dem privaten SSH-Schlüssel signiert. `sasd-monitor-auth-import` prüft Signatur, Host- und Rollen-/Check-Zuordnung, Ablaufzeit, Zeitfenster und Replay-Sequenz, bevor M1-Daten geschrieben werden.

Dies ist ein Datei-Austausch- und Staging-Vertrag, kein Nachweis eines sicheren Netzwerktransports. Ein späterer SSH-Transport benötigt eine eigene Prüfung von Hostschlüsseln, Kontobeschränkungen, Dateirechten und Aufräumen. Dieses Repository implementiert keinen SSH-Listener, keine `authorized_keys`-Command-Schranke und keinen beliebigen Remote-Befehlspfad.

Der begrenzte SSH-Adapter ist in [transport.de.md](transport.de.md) dokumentiert. Er benötigt weiterhin einen administrativ eingerichteten OpenSSH-Dienst und einen nativen Integrationstest.

## Sperrung und Wiederaufnahme

`disable` verhindert sofort authentifizierte Importe und meldet den Rechner im M1-Zyklus als purple mit Hinweis auf die gesperrte Registrierung. `enable` setzt einen noch gültigen Datensatz auf `approved`; anschließend ist eine neue signierte Sequenz nötig. Sequenzen bleiben über Sperrung und Wiederaufnahme erhalten. Abgelehnte Hosts haben keinen aktiven Registrierungsdatensatz.

## Grenzen und Diagnose

Die Steuerung verwendet private Textdateien in einem vertrauenswürdigen Betreiberpräfix. Unsichere Bezeichner, fehlerhafte Schlüssel, symbolische Dateien, abgelaufene Anträge/Freigaben, unzulässige Rollen/Checks, doppelte Checks, alte Zeitstempel, manipulierte Signaturen und wiederholte Sequenzen werden zurückgewiesen. Feindliche konkurrierende Schreiber, kompromittierte private Schlüssel, vertrauenswürdige Zeit, Schlüsselwechsel und Transportautorisierung bleiben offen.

Die vollständige Offline-Demonstration ist:

    examples/m2-enrollment-lab.sh

Die Negativ- und Zwei-Client-Regression ist `tests/m2-enrollment.sh`. Beide benötigen `ssh-keygen`, temporäre Verzeichnisse, keine root-Rechte und kein Netzwerk.
