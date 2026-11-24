# M2.1-SSH-Transport

English: [English version](transport.md)

Der Transportadapter überträgt einen vorhandenen `SASD-AUTH-1`-Payload über einen vom Betreiber eingerichteten OpenSSH-Dienst. Er fügt keinen Listener, keine Serversschlüsselerzeugung, keine Enrollment-Freigabe und keine Remote-Shell hinzu.

Der Client erhält alle Vertrauensparameter ausdrücklich:

    bin/sasd-node-send --server monitor.example.invalid --user sasd --port 22 \
      --identity /path/client/etc/identity --known-hosts /path/client/etc/known_hosts \
      --payload /path/status.payload --signature /path/status.payload.sig --dry-run

`--send` wird erst nach Prüfung und Eintrag des Server-Hostschlüssels in der eigenen `known_hosts`-Datei verwendet. Der Befehl nutzt strikte Hostschlüsselprüfung, `IdentitiesOnly`, Batch-Modus, keine Agent-/Verbindungsweiterleitung, kein PTY und keine beliebigen SSH-Optionen. Der einzige Remote-Befehl ist `sasd-monitor-receive --stdio`.

Payload und Signatur werden mit begrenzten Byte-Längen über stdin gerahmt. Der Receiver lehnt falsche Hosts, ungültige, zu große, abgeschnittene oder nachfolgende Daten sowie alles ab, was der bestehende authentifizierte Import ablehnt. Ein Dry-Run baut keine Netzwerkverbindung auf.

Für jeden eingeschriebenen Client wird ein unprivilegiertes Konto mit einem `authorized_keys`-Eintrag und Forced Command empfohlen, der Host und Serverkonfiguration bindet, zum Beispiel:

    command="/srv/sasd/bin/sasd-monitor-receive --config /srv/sasd/etc/sasd-monitor.conf --host node.example.invalid --stdio",no-pty,no-agent-forwarding,no-port-forwarding,no-X11-forwarding ssh-rsa AAAA...

Absolute Pfade, Fingerprint und Rechte sind vor der Installation zu prüfen. Der Receiver ruft ausschließlich `sasd-monitor-auth-import` auf und führt keine Befehls- oder Pfadangaben des Clients aus. Der Installer ändert weder `sshd_config`, Konten, `authorized_keys`, `/etc` noch Cron. Der Server-Hostschlüssel ist vom Payload-Schlüssel des Clients getrennt. `StrictHostKeyChecking=no` und eine beschreibbare `known_hosts`-Datei sind unzulässig.

`tests/m2-transport.sh` prüft Framing und Ablehnungen offline. In dieser Arbeitskopie sind `ssh` und `ssh-keygen`, aber kein `sshd` vorhanden; ein echter eingeschränkter Transfer mit Ablehnung bleibt daher offen. Für die native Abnahme sind eine isolierte Wegwerf-VM oder ein ausdrücklich freigegebenes lokales `sshd`, Versionsnachweis, Hostschlüssel-Einrichtung sowie ein erfolgreicher und ein abgelehnter Transfer nötig.

Der Receiver serialisiert Einsendungen mit einem privaten Lock und legt Dateien exklusiv mit Modus 0600 ab. Der authentifizierte Import bleibt für Signatur, Enrollment-Zustand, Rollen-/Check-Zuordnung, Ablauf und Replay-Sequenz maßgeblich.
