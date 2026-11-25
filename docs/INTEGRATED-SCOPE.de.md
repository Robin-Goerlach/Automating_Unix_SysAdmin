# Umfang der integrierten Infrastruktur

English: [English version](INTEGRATED-SCOPE.md)

Dieses Dokument überführt den dauerhaften Entwicklungsauftrag in einen repositorybezogenen Umfang. Es ist eine Arbeitsarchitektur und Abnahmegrenze, keine Behauptung, dass jedes aufgeführte Produkt implementiert ist.

## Richtung und Profile

SASD bleibt eine eigenständig entwickelte Sammlung kleiner Unix-Verwaltungsprogramme. Das Profil 1999 bevorzugt POSIX-Shell, Perl, awk, sed, cron und Textdateien. Getrennte spätere Profile können CFEngine 2, Nagios, Ganglia, FAI/Kickstart/JumpStart und Praktiken von 2002–2009 abbilden. CFEngine 1 und 2, NetSaint und Nagios sowie Big Brother und Big Sister bleiben getrennte Integrationen. Kein Buchquelltext, proprietärer Produktcode oder erfundene historische Herkunft gehört in dieses Repository.

Langfristig verbindet das System ein versioniertes Host-/Service-Inventar mit unabhängigen Konfigurationsgeneratoren, Monitoring-Adaptern, Provisioning-Vorbereitung und statischen Betriebsberichten. Ein zentraler Daemon oder eine Datenbank ist nicht erforderlich. Geheimnisse bleiben außerhalb des normalen Inventars.

## Aktuelle Checkpoint-Grenze

Checkpoint A umfasst reproduzierbare Offline-Härtung, Test- und Release-Prüfungen sowie eine Kompatibilitätsmatrix. Die aktuelle Evidenz umfasst begrenzte Archivbehandlung, negative Netboot-/Postinstall-Tests, Batchvalidierung und kooperierende Sperren im Status-Store. Crash-atomare Mehrdatei-Commits, Schutz gegen feindliche TOCTOU-Angriffe sowie native Produkt- und historische Unix-Abnahmen bleiben offen.

Checkpoint B wird schrittweise umgesetzt:

- `site/hosts.tsv`, `site/roles.tsv`, `site/checks.tsv` und `site/services.tsv` bilden das gemeinsame Textmodell.
- `bin/sasd-site-inventory`, `bin/sasd-site-services`, `bin/sasd-site-classes` und `bin/sasd-site-audit` prüfen und selektieren vorhandene Arbeiten.
- `bin/sasd-host-admin` bietet lokale CRUD-Verwaltung mit `--apply` als Schreibschranke.
- `bin/sasd-site-config` erzeugt eine deterministische Host-/Service-Auswahl im Staging und einen Konsistenzbericht; es behauptet nicht, native CFEngine-, MRTG-, Nagios-, DHCP- oder TFTP-Syntax zu erzeugen.

Weitere B-Schritte sind produktspezifische Generatoren, eine kontrollierte Deploy-/Apply-Grenze, historische Ereignisaufbewahrung und ein vollständigeres Offline-Ende-zu-Ende-Labor. Deaktivierung oder Entfernung eines Hosts darf historische Monitoringdaten nicht löschen. Der aktuelle Hostzustand wird getrennt vom aktiven Inventar geführt; persistente Ereignishistorie ist noch offen.

## Sicherheits- und Betriebsgrenzen

Administrative Schreibvorgänge benötigen eine ausdrückliche Operation und, soweit zutreffend, `--apply`. Eingaben sind zeilenorientierte TSV-Daten mit begrenzten Bezeichnern, Duplikatprüfung, Pfadvalidierung und ohne Shell-Auswertung. Staging-Ziele müssen Wegwerfziele sein und werden erst nach Validierung ersetzt. Kein Kommando startet Dienste, öffnet Listener, verändert Blockgeräte, installiert Pakete, genehmigt Enrollment oder kontaktiert Inventaradressen.

Datenbank-Monitoring dient ausschließlich lesenden technischen Gesundheitsprüfungen realer Unternehmensdatenbanken, niemals dem Kopieren von HR-, CRM-, Vertriebs- oder Kundendaten. Adapter benötigen geringste Rechte, begrenzte Zeit/Ausgabe, Parameterbindung und versionsbezogene Abfragen. Nicht unterstützte Prüfungen sind UNKNOWN/NOT SUPPORTED und nicht erfolgreich. Firebase ist ein späterer Cloud-/NoSQL-Adapter; Firebird ist ein eigenes Datenbankprodukt; PL/SQL ist Oracle-spezifisch.

## Geplante Integrationsschichten

Der Auftrag umfasst CFEngine 1/2, MRTG, RRDtool, Big Brother, Big Sister, NetSaint, Nagios, Ganglia, SASD-Monitoring, BOOTP/DHCP, TFTP, Golden-Client-/Image-Abläufe, automatisierte Installation, Datenbankprüfungen und eine spätere lesende Administrationskonsole. Jede Integration benötigt eigene Versionsmatrix, Fixture und Negativtests. Eine Konfigurationsvorlage ist kein Nachweis nativer Kompatibilität. Moderne CI beweist nur die genannte moderne Umgebung.

Infrastruktur- und Client-Installer beginnen mit Dry-Run und Wegwerf-Prefix-Staging. Der Installationsserver orchestriert etablierte DHCP-/TFTP-/Installationsprogramme statt einen neuen Netzwerkdaemon zu implementieren. Netzwerkboot, historische Betriebssysteme und Produktivänderungen benötigen eigene dokumentierte native Abnahmen.

## Abnahmesprache und Releases

Verwende `PASS`, `FAIL`, `SKIPPED`, `NOT TESTED`, `BLOCKED` und `PENDING` präzise. V1.0.0 bleibt unverändert. V1.1.0 wird vor den dokumentierten nativen M6-/M7-Gates nicht veröffentlicht. Spätere integrierte Arbeiten dürfen nicht stillschweigend in diesen Release gemischt werden. Jede wesentliche englische Dokumentationsänderung erhält eine deutsche `.de.md`-Fassung.

Der maßgebliche dauerhafte Auftrag steht in `../logs/MASTER-ASSIGNMENT.md`; er wird zu Beginn jeder Entwicklungssitzung gelesen und weder durch diese Zusammenfassung noch durch `LAST-SESSION.md` ersetzt.
