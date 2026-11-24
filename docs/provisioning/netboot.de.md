# M6 Netzwerkboot und TFTP-Staging

English: [English version](netboot.md)

M6 stellt derzeit nur die Offline-Vorbereitung bereit. `bin/sasd-netboot-config` prüft einen kontrollierten Host-/Profil-/Image-Satz und erzeugt genau einen ausgewählten Dialekt: `isc-dhcp`, `dnsmasq` oder die getrennte `bootp`-Vorlage. Es startet kein DHCP, sendet keine Pakete, installiert keinen Dienst und ändert kein vorhandenes Netz.

Host-Spalten:

```text
hostname  MAC  IPv4  bootserver  tftp-root  boot-file  architecture  install-profile
```

Profil-Spalten:

```text
profile  os  architecture  method  source  image-id  role  partition-layout  postinstall  monitoring-profile
```

Image-Spalten sind `image-id`, `version`, `sha256` und `source`. Das referenzierte Image ist in dieser Phase nur Metadaten; M5-Archive bleiben Dateisystemarchive und werden nicht stillschweigend als bootfähige Medien behandelt. Der Generator lehnt doppelte Namen, MACs und IPv4-Adressen, unbekannte Images/Profile, Architekturabweichungen, Traversal, Shell-Metazeichen und geheimnisartige Profilwerte ab.

`bin/sasd-netboot-stage` kopiert eine ausdrücklich ausgewählte Bootdatei in ein ausdrücklich ausgewähltes Labor-TFTP-Root. Es prüft die Quellprüfsumme, lehnt Symlink-Roots und unsichere Pfade ab, schützt vorhandene Dateien und führt ein `tftp-manifest.tsv`. Es lädt keinen Bootloader herunter, führt ihn nicht aus und authentifiziert ihn nicht.

## Dialekt- und Zeitgrenzen

- `isc-dhcp` ist eine ISC-DHCP-artige Hostdeklaration; die konkrete Syntax muss gegen die eingesetzte ISC-DHCP-Version geprüft werden.
- `dnsmasq` erzeugt `dhcp-host`- und markierte `dhcp-boot`-Direktiven. Das ist ein späterer kompakter Labordienst und keine BOOTP-Aussage für 1999.
- `bootp` erzeugt eine getrennte klassische Hostdeklaration. Es emuliert nicht die Datenbank eines bestimmten Herstellers.
- Kandidaten für Solaris JumpStart, Red Hat Kickstart und Debian FAI liegen unter `site/install/adapters/`. Es sind eigenständige kleine Vorlagen und bleiben unverifiziert, bis die benannte OS-/Installer-Version tatsächlich ausgeführt wird.

Der Standardtest ist `tests/m6-netboot.sh`; `examples/m6-netboot-lab.sh` demonstriert nur Konfiguration und Staging. Ein echter Boot benötigt isolierten Server, TFTP-Dienst, Installationsquelle und Wegwerfclient. Eine solche Umgebung wurde weder verändert noch als abgenommen ausgegeben.
