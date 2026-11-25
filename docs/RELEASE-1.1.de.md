# SASD-1.1-Entwicklungsumfang und Abnahme

English: [English version](RELEASE-1.1.md)

Status: Entwicklungscheckpoint bis zur Offline-Abnahme von M7 abgeschlossen. Ein `v1.1.0`-Tag ist noch nicht zulässig.

Abnahmekontrolle am 25.11.2026: Der verfügbare Host ist WSL2 (`5.15.167.4-microsoft-standard-WSL2`). `virsh`, QEMU, `qemu-img`, `tcpdump`, `sshd` und ein TFTP-Dienst fehlen; es gibt kein libvirt-Netz und keine Wegwerf-VM. Der lesende Preflight meldet daher `SKIPPED`. Es wird kein nativer Netzwerkboot, keine Installation und keine native Postinstallation behauptet.

## Auf `main` enthalten und verifiziert

- M5-Golden-Client-Audit, TAR-Capture, Manifest-/Checksum-Katalog und sicherer Dateisystem-Restore.
- M6-Offline-Erzeugung von BOOTP-, ISC-DHCP- und dnsmasq-artiger Konfiguration, Profilprüfung und TFTP-Staging mit Prüfsumme.
- Kleine Kandidatenvorlagen für Solaris JumpStart, Red Hat Kickstart und Debian FAI, ausdrücklich unverifiziert gegen native Installer.
- M7-Postinstallation in einem ausdrücklichen Präfix, neue Client-Identitäten, Image-Versionsauswahl und offener Enrollment-Antrag.
- Wiederverwendung der bestehenden Betreiberfreigabe, signierten Statusdatei und des authentifizierten M1-Imports ohne zweiten Registrierungsdienst.
- Ablehnung doppelter Identitäten, veralteter Image-Versionen, abgelehnter Hosts, unsicherer Profilwerte und stiller Reinstallation aktiver Enrollment-Datensätze.
- Offline-End-to-End-Labor `examples/sasd-provisioning-lab.sh`.
- Lesender nativer Labor-Preflight `tests/m6-kvm-preflight.sh` und reproduzierbares Debian/KVM-Verfahren in [provisioning/kvm-lab.de.md](provisioning/kvm-lab.de.md).

## Enthalten mit Einschränkungen

- Alle M5–M7-Abnahmen verwenden derzeit temporäre Verzeichnisse und simulierte normale Dateien. Es werden keine Blockgeräte beschrieben und keine Produktivnetze konfiguriert.
- Konfigurationsdialekte werden für die benannten Produkte erzeugt; das Parsen durch einen nativen Dienst ist jedoch keine Netzwerkinstallationsabnahme.
- Das M5-Archiv ist nicht bootfähig; Hardware-, Partitions-, Bootloader- und Treiberkompatibilität bleiben Plattform-/Betreiberaufgaben.
- Historische JumpStart-/Kickstart-/FAI-Kompatibilität ist unverifiziert. Die aktuelle CI läuft nur auf aktuellem Linux.

## Noch offene Pflichtgates

- Ein echter reproduzierbarer Netzwerkboot- oder Installationsversuch in einem ausdrücklich isolierten Wegwerflabor mit beobachtetem TFTP-Transfer und erreichtem Installationszustand.
- Native Postinstallation nach dieser Installation einschließlich neuer Identität, Enrollment-Antrag, Freigabe und Monitoring-Status.
- Der Nachweis muss genaues OS, Dienstversionen, Bootclient, isoliertes Netz, Kommandos, Logs und Cleanup aufzeichnen.

Da diese Gates offen sind, bleibt das Projekt nach M7 auf `main`; ein stabiler `v1.1.0`-Release wird nicht veröffentlicht. Der bestehende Tag und Release `v1.0.0` bleiben unverändert.
