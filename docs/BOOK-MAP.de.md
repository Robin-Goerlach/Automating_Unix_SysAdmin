# Themenübersicht: Campi/Bauer (2009) und eigenständige SASD-Arbeit

English: [English version](BOOK-MAP.md)

Hauptreferenz ist Nate Campi und Kirk Bauer, *Automating Linux and Unix System Administration*, 2. Auflage, Apress (2009), ISBN 978-1-4302-1059-7. Inhalt und Beispielcode sind urheberrechtlich geschützt. Diese Datei ist eine **konzeptionelle Themenübersicht**, kein abgeleiteter Implementierungsplan und keine Reproduktion des Buchcodes.

Der Text von 2009 entstand deutlich nach dem Referenzprofil 1999. Die SASD-Module wurden daher unabhängig und zeitlich getrennt entworfen; Tutorialschritte, Namen, Rechner, Verzeichnisbäume und Policy-Texte werden nicht übernommen.

| Buchthema | Eigenständiger SASD-Bedarf | Modul | Profil | Status |
| --- | --- | --- | --- | --- |
| Automatisierungsgrundlagen | Rechnerinventar und Rollen | host-facts, site-inventory, site-classes | P0–P3 | Offline implementiert |
| Praktische Automatisierung | Vorhersagbare Fehler, Idempotenz | Rollback-Protokoll und Negativtests | alle | Teilweise implementiert |
| SSH-Administration | Geprüfter, begrenzter Fernzugriff | Schlüssel- und Vertrauensprüfung | P4/P5 | Geplant |
| CFEngine | Sollzustand erkennen | config-drift, Rollen-Audit, CFEngine-1-Kandidat | P1/P4 | Audit implementiert, native CFEngine-Prüfung offen |
| Infrastruktur-Bootstrap | Aufnahme von Rechnern und Baselines | Enrollment, Rollenmanifeste, Staging | P4/P5 | Geplant |
| Automatische Installation | Isolierte Gastinstallationen | FAI-, Kickstart- und JumpStart-Adapter | P4/P5 | Geplant |
| Gemeinsame Infrastruktur | NTP, DNS, Konten, Mail | Prüf- und Verteilungshelfer | P1–P5 | NTP-Fixture vorhanden |
| Anwendungsverteilung | Sicheres Deployment und Rollback | Manifestvergleich, spätere Transportadapter | P3–P5 | Vergleich vorhanden |
| Status und Logs | Betreiberstatus ohne große Plattform | Statusspeicher, Bericht, Syslogparser | P0–P5 | Implementiert |
| Überwachung | Zustände, Metriken, Historie | M1-Server, Statusboard, MRTG- und RRD-Brücke | P2–P5 | Offline implementiert |
| Wartung/Wiederherstellung | Konfigurationshistorie und Restore | Backup- und Restore-Prüfung | P0–P5 | Geplant |
| Sicherheit | Rechte, Prozesse, Konfigurationsprüfung | Lesende Prüfungen und kontrollierte Änderungen | P1–P5 | Teilweise implementiert |

## Bewusste SASD-Ergänzungen

1. Ein eigenständiges Kompatibilitätsprofil für Unix-Betrieb um 1999.
2. Ein eigener vierfeldriger SASD-TSV-Statusvertrag statt eines Big-Brother-Drahtprotokolls.
3. Die zeitliche Trennung CFEngine 1 zuerst, CFEngine 2 später.
4. Eine dokumentierte Portabilitäts- und Abnahmeschranke für ältere Unix-Systeme.
5. Die Trennung von Prüfung, Änderung und sicherem Rollback.
6. Die Beschränkung alter Netzwerkdienste auf isolierte Umgebungen.

Keine Namen, Texte, Verzeichnisbäume, Beispiel-IP-Bereiche, Firmeninfrastruktur, Policies oder Listings aus dem Buch werden übernommen.
