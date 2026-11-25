# Wegwerfbares Debian/KVM-Netzwerkboot-Labor

English: [English procedure](kvm-lab.md)

Dies ist die native M6/M7-Abnahme. Sie benötigt einen freigegebenen Debian-KVM/libvirt-Host, eine neu erzeugte Wegwerfplatte und ein isoliertes Netz ohne Weiterleitung. WSL allein genügt nicht.

Lesenden Preflight ausführen:

```sh
tests/m6-kvm-preflight.sh
tests/m6-kvm-preflight.sh --require
```

Die Standardform meldet bei fehlenden Voraussetzungen `SKIPPED`; `--require` endet mit 2. Beide Formen erzeugen weder Netz, VM, Platte, Dienst noch Listener.

## Sicherheitsgrenze

Nur einen freigegebenen KVM-Host verwenden. Keine vorhandenen libvirt-Netze, Domains, Platten, Bridges, DHCP-Dienste, Router, Firewallregeln oder physischen Geräte wiederverwenden. Erzeugung von Netz, VM, Platte und privilegiertem DHCP/TFTP-Dienst benötigt eine gesonderte Freigabe; das Repository automatisiert dies nicht.

Datum, OS-, libvirt-, QEMU-, qemu-img-, dnsmasq- und SSH-Versionen sowie den Preflight in einem Nachweisverzeichnis außerhalb des Repositories speichern.

## Laborrezept

Ein nur im Labor verwendetes RFC-5737-Netz wie `192.0.2.0/24` verwenden, mit Server `192.0.2.1` und Gast `192.0.2.40`; vorher auf Überschneidungen prüfen. Ein no-forwarding-libvirt-Netz, eine neue VM und eine neue qcow2-Platte erzeugen. Netzdefinition, `virsh dumpxml` und `qemu-img info` speichern. Keine physische oder vorhandene Platte einbinden.

Einen aktuellen Debian-Netboot-Baum lokal vorbereiten und Version, Installerstand, Architektur, Quelle und SHA256 notieren. SASD-Fragment prüfen und nur den verifizierten Loader stagen:

```sh
bin/sasd-netboot-config --hosts lab/hosts.tsv --profiles lab/profiles.tsv --images lab/images.tsv --format dnsmasq --out evidence/dnsmasq.conf --apply
bin/sasd-netboot-stage --source lab/boot/pxelinux.0 --tftp-root "$LAB_TFTP_ROOT" --profile debian-current --boot-file pxelinux.0 --sha256 "$PXELINUX_SHA256" --apply
```

Bei UEFI den passenden Debian-EFI-Loader verwenden. `tftp-manifest.tsv` speichern. Konfiguration und Prüfsumme sind erst dann native Nachweise, wenn Dienst und Gast beobachtet wurden.

## Erforderlicher nativer Nachweis

Nur den isolierten DHCP/TFTP-Dienst und den Wegwerf-Gast starten. Logs, Paketmitschnitt und Gastkonsole speichern. Der Nachweis muss DHCP-Zuweisung zur erwarteten MAC, Profil und Bootdatei, erfolgreichen TFTP-Transfer, Debian-Installer, Installation auf die neue Platte, Neustart davon und die installierte Debian-Version aus Konsole und authentifizierter SSH-Sitzung zeigen.

Nach der Installation den bestehenden M7-Weg ausführen: `sasd-postinstall`, Antragimport, ausdrückliche Betreiberfreigabe, `sasd-node-status`, freigegebenen M2.1-Fixed-Command-Transfer, `sasd-monitor-auth-import` und Monitoring-Bericht. Neue Identität/Fingerprint bestätigen. Ungeprüfte, geänderte, wiederholte, deaktivierte, veraltete und aktive Reinstallationsfälle müssen abgelehnt werden. Der Installer darf nicht selbst freigeben.

Versionen, Netz-/Gastdefinition, Plattenmetadaten, SASD-Ein-/Ausgaben, Logs, Mitschnitt, Monitoring, Negativtests und Bereinigung speichern; Schlüssel redigieren. Nach dem Stoppen nur die neue Domain, das neue Netz, TFTP-Verzeichnis und die neue qcow2-Platte entfernen.

Dieses Verfahren wurde in der aktuellen WSL2-Umgebung nicht ausgeführt. Die native Abnahme bleibt offen.
