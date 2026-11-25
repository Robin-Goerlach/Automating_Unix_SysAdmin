# SASD Automating Unix SysAdmin — Roadmap

English: [English version](ROADMAP.md)

**Stand:** 24.11.2026. **Kompatibilitätsumgebung:** Unix-Stand um 1999. Das Buch von 2009 dient nur als Themenreferenz für spätere Profile.

## Abnahmestufen

- **Implementiert:** Quelltext ist vorhanden und lokales Verhalten ist getestet.
- **CI-geprüft:** Aktueller automatisierter Test ist erfolgreich; dies beweist kein historisches Betriebssystem.
- **Integration geprüft:** Ein versioniertes externes Programm wurde tatsächlich ausgeführt.
- **Historisch geprüft:** Ein dokumentierter Lauf auf der genannten Originalkombination war erfolgreich.
- **Geplant:** Kein Code und keine Abnahmebehauptung.

Fixture-Tests dürfen niemals als Live-Netzwerk oder historische Kompatibilität bezeichnet werden.

## R2 — Rollenverwaltung und CFEngine 1

- [x] Dateibasiertes Rechner- und Rolleninventar.
- [x] Deterministische Klassen- und Rollenauflösung sowie lesendes Drift-Audit.
- [x] Eine versionierte Service-Auswahldatei mit Host-Zuordnungsprüfung; die Auswahl bleibt schreibgeschützt und unabhängig von der Dienststeuerung.
- [x] Ausdrückliche Hostoperationen mit `sasd-host-admin`, `--apply`-Schranke und getrenntem enabled/disabled/removed-Zustand.
- [x] Deterministisches gemeinsames Host-/Service-Staging mit `sasd-site-config`, einschließlich Ausschluss deaktivierter Hosts und Schutz vor vorhandenen Ausgabeordnern.
- [x] Geprüfte Host-Lebenszyklusereignisse über add/update/enable/disable/remove hinweg aufbewahren.
- [ ] Weitere produktspezifische Generatoren, kontrolliertes Deploy/Apply und Migration/Versionierung.
- [ ] CFEngine-1.4-Syntax mit Originalprogramm und Wegwerf-VM prüfen.
- [x] Eigenständige Konfigurationsprüfung ohne CFEngine.
- [ ] Staging, Backup und ausdrückliches Apply mit Rollback.

## M1 — Zentraler SASD-Monitoring-Server

- [x] Begrenzte Konfiguration und Installer mit Dry-run/Apply-Schranke.
- [x] Wiederverwendung von R2-Inventar und Check-Zuordnung.
- [x] Streng validierter lokaler Statusimport.
- [x] Frische, Zustandswechsel, begrenzte Historie und statischer HTML-Bericht.
- [x] MRTG-Kandidat ohne SNMP-Zugangsdaten oder Polling.
- [x] RRDtool-Pfad und optionale Abhängigkeit dokumentiert.
- [x] Grenzen für NetSaint, spätere Nagios/Ganglia, MRTG/RRD und CFEngine dokumentiert.
- [x] Enrollment-Lifecycle ohne remote akzeptierte Meldungen definiert.

**Abnahme:** Offline-Installer, Zustandswechsel, Stale-Erkennung, HTML-Escaping, begrenzte Historie, kein Listener und keine privilegierte Operation. Native externe Integrationen bleiben getrennt.

## M2 — Unix-Node-Bootstrap und sichere Registrierung

- [x] SSH-Public-Key-Identität mit ausdrücklicher Betreiberfreigabe.
- [x] Signierte Offline-Statusdateien mit Rollen-/Checkprüfung, Ablauf, Zeitfenster und Replay-Sequenz.
- [x] Begrenzter Wegwerf-Client mit Apply-Schranke, Schlüssel und Cron-Vorlage.
- [x] Dauerhafter Freigabe-, Ablehnungs-, Sperr-/Wiederaufnahme-Lifecycle mit Audit-Ereignissen.
- [x] M1-Einbindung dynamisch registrierter und gesperrter Rechner.
- [x] SSH-Transportadapter mit festem Befehl, strikten Client-Host-Key-Optionen und begrenztem Framing.
- [x] Native Live-SSH-Abnahme mit eingeschränktem OpenSSH-Fixture und Hostschlüssel-Ablehnung (CI-Nachweis); Austausch, Wechsel und Recovery kompromittierter Schlüssel bleiben offen.
- [ ] Keine Remote-Shell und keine beliebige Befehlsausführung; diese Grenze bleibt bestehen.

**Abnahme:** Zwei-Client-Offline-Labor mit einem genehmigten und einem abgelehnten Client, signiertem Import, Manipulations-/Replay-/Sperrtests, statischem Bericht, keinem Listener und ohne privilegierte Operation. Dies ist keine Abnahme eines Netzwerktransports.

## V1.0-Kernumfang

Der begrenzte V1.0-Kern ist in [RELEASE-1.0.de.md](RELEASE-1.0.de.md) eingefroren: M2.1-Transport, ausgewählte MRTG-/RRDtool-Integration, sichere Installer, ablaufende Maintenance-/Acknowledgement-Annotationen, Backup/Restore und zweisprachige Betriebsdokumentation. Die Evidenzgates sind für `7920cad` abgeschlossen; die Veröffentlichung bleibt als letzter Publikationsschritt.

## R0 — Eigenständige Grundlage

- [x] POSIX-Shell-Systeminformationen und `df`-Auswertung.
- [x] Eigenes vierfeldriges Statusprotokoll, Statusboard und Golden-File-Vergleich.
- [x] MRTG-Zähleradapter, optionaler RRDtool-Wrapper und synthetische Negativtests.
- [x] Offline-Prüfungen für passwd, Syslog, NTP und Benutzer-Crontabs.
- [ ] Härtung gegen Spool-Symlinks, Kürzung und konkurrierende Schreiber.
- [ ] Perl-5.004-Kompatibilität beweisen oder enger abgrenzen.

## R1 — Unix-Werkzeuge vor 1993

- Passwort-/Gruppenprüfung ohne untrusted NSS-Annahmen.
- Cron- und Startdienstinventar, Syslogfamilien und Dateirechteprüfung.
- Tar-/Dump-/Restore-Inventar und Wiederherstellungsnachweis.
- Getrennte Bourne-Shell-, awk- und sed-Programme statt eines Gesamtframeworks.

## R3 — MRTG, SNMP und RRDtool

- [x] Vierzeilige externe MRTG-Zählerausgabe und opt-in-RRDtool-Wrapper.
- [x] Echtes MRTG 2 in einem isolierten Wegwerf-Präfix mit Diagramm prüfen.
- [ ] Zählerüberlauf, 32-/64-Bit-Grenzen und 5-Minuten-Abfrage dokumentieren.
- [ ] SNMP v1/v2c nur in isolierter Umgebung ohne eingebettete Communities.
- [x] RRDtool create/update/fetch/graph mit festen Zeitstempeln und Archivdefinitionen prüfen.
- [ ] Nagios-/Ganglia-Adapter erst in späteren Profilen.

## R4 — Unabhängige zentrale Überwachung

- [x] Lokaler Statusspeicher, Statusboard, Stale-Nachweis und M1-Zustand.
- [ ] Quittierung, Wartungszustand, Drosselung und Eskalation.
- [ ] Lesendes TUI oder CGI für Betreiber.
- [ ] Eingangsdaemon erst nach Authentifizierung, begrenztem Protokoll und Isolation.
- [ ] Separate Lizenz- und Protokollprüfung zu Big Brother/Xymon.

## R5 — Automatisierte Bereitstellung

- SSH-Schlüsselprüfung, Bootstrapping-Manifeste und Staging.
- FAI-, Kickstart- und Solaris-JumpStart-Adapter.
- Baselines für NTP, DNS, Konten, NFS und Mail.
- Apache-/rsync-Verteilung mit ausdrücklichem Rollback.
- CFEngine-2-Beispiele getrennt von CFEngine 1.

## R6 — Logs, Backups und Sicherheit

- Zentrale Syslogaufbewahrung mit Integritätsnachweis.
- Reproduzierbare Restore-Übungen.
- SUID-, Rechte-, SSH-, sudo-, TCP-Wrapper- und Firewall-Audits.
- Sicherheitsupdateprüfung ohne pauschales Auto-Patching.

## R7 — Prüfung historischer Plattformen

Mögliche isolierte Gäste sind FreeBSD 3/4, OpenBSD 2/3, Debian 2.x, Red Hat Linux 6.x und Solaris 7/8, soweit rechtmäßig verfügbar. Namen allein bedeuten keine Unterstützung.

**Abnahmekriterium:** Wiederholbarer Lauf mit genau benanntem System, Programmversion, Kommandoausgabe und Toolchain. Modernes Linux ist Entwicklungsplattform, kein Ersatz für ein historisches System.

## Umfang und Priorität

Priorität haben R0-Härtung und R1-Werkzeuge; R2–R4 können bei unabhängigen Schnittstellen parallel gepflegt werden, R5–R7 folgen der Abnahme. Offene Entscheidungen betreffen Paketierung, Rechte an Installationsmedien, Bedrohungsmodell des zentralen Monitorings, Transportsicherheit und die rechtliche Machbarkeit von Big-Brother-Kompatibilität.

## V1.1-Provisionierungsmeilensteine

### M5 — Golden Client und Dateisystem-Imaging

- [x] Lesendes Audit des Referenzbaums mit ausdrücklich nicht geprüften plattformspezifischen Feldern.
- [x] TAR-Capture mit Quelle/Repository, Dry-Run/Apply, Ausschlüssen, Manifest und SHA256-Datensatz.
- [x] Dateibasierter Image-Katalog und Prüfsummenprüfung.
- [x] Sicherer Restore in ein neues Wegwerfverzeichnis mit Prüfungen von Archivpfaden, Links und Spezialdateien.
- [x] Offline-Positiv- und Negativabnahme ohne Root, Netzwerk oder Blockgeräte.
- [ ] Bootfähigkeit, Raw-Datenträger-Restore, Hardwarekompatibilität und historische Plattformabnahme.

### M6 — Netzwerkinstallation

- [x] Kontrollierte Erzeugung von BOOTP-/DHCP-/dnsmasq-Konfiguration und TFTP-Staging (nur offline).
- [x] Explizite Installationsprofile und getrennte Kandidaten für JumpStart/Kickstart/FAI (native Syntax unverifiziert).
- [ ] Isolierte native Netzwerkboot-Abnahme.

### M7 — Postinstallation und Monitoring-Enrollment

- [x] Host-Personalisierung in einem ausdrücklichen Präfix mit neu erzeugten Identitäten.
- [x] Wiederverwendung des bestehenden M2-Enrollment und authentifizierten M2.1-Imports ohne automatische Freigabe (Offline-Abnahme).
- [x] Abnahme von Reinstallation, doppelter Identität, veraltetem Image und Ablehnung (Offline-Abnahme).
- [ ] Native Postinstallation nach echter Netzwerkinstallation sowie automatisierter Schlüsselwechsel/-Recovery.

### M7-D — Moderne Debian-Checklistenerweiterung (Entwicklungsbranch)

- Nummerierter Task-Dispatcher, Quellzeilen-Zuordnung und explizite offene Zustände; nur Kandidatenerzeugung.
- R2-Inventar bleibt einziges Hostregister; validierte Standort- und Hostpolicy ergänzen. Zentrale Adapter und Entfernen/Deaktivieren bleiben geplant.
- Geschütztes natives Apply, Paket-/Dienstprüfung, privater Inventarreport, Idempotenz, Backups, Rücknahme und Reboot-Resume vor Laborabnahme implementieren. M7-Betreiberfreigabe bleibt unverändert.
- Siehe [provisioning/debian-client.de.md](provisioning/debian-client.de.md). Das ändert weder das native V1.1-Abnahmegate noch historische Profile.
