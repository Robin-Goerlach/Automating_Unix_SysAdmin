# Eigenständige Entwicklung und Quellenprovenienz

English: [English version](PROVENANCE.md)

## Projektcharakter

SASD ist eine 2026 neu erstellte, eigenständige Sammlung von Systemverwaltungsprogrammen. Kompatibilitätsprofile beschreiben die technische Zielumgebung, nicht das tatsächliche Datum, die Urheberschaft oder die Versionsgeschichte des Codes. Alle Git-Metadaten bleiben echt.

## Referenzmaterial

- Nate Campi und Kirk Bauer, *Automating Linux and Unix System Administration*, 2. Auflage, Apress (2009), ISBN 978-1-4302-1059-7. Diente zur Themenorientierung, nicht als Quelltextvorlage.
- David N. Blank-Edelman, *Automating System Administration with Perl*, 2. Auflage, O'Reilly (2009). Diente als fachlicher Kontext; kein Buchcode wurde übernommen.
- SASD-Sysadmin/freeware, https://github.com/SASD-Sysadmin/freeware. Als unabhängige Anregung betrachtet; keine Historie und kein direkter Codeimport.

## Dokumentation Dritter

- CFEngine — https://docs.cfengine.com/
- GNU-CFEngine-Archiv — https://ftp.gnu.org.uk/gnu/cfengine/
- GNU-CFEngine-Referenz — https://www.gnu.org/software/cfengine/docs/cfengine-Reference.html
- MRTG — https://mrtg.org/mrtg/doc/mrtg-reference.en.html
- RRDtool — https://oss.oetiker.ch/rrdtool/
- Big Brother — https://linuxgazette.net/issue15/bb-info.html
- Big Sister, Konfigurationsreferenz und Änderungshistorie — https://www.bigsister.ch/bigsister.html, https://www.bigsister.ch/pdoc/CONFIG.html, https://www.bigsister.ch/pdoc/CHANGES.html
- Nagios — https://www.nagios.org/about/history/
- Nagios-Altrelease-Index — https://sourceforge.net/projects/nagios/files/OldFiles/ (führt nagios-1.0a7.tar.gz mit Zeitstempel 13.03.2002 auf).
- Nagios-Objektdefinitionsreferenz — https://assets.nagios.com/downloads/nagioscore/docs/nagioscore/3/en/objectdefinitions.html (für das Objektvokabular, nicht als exakte Parser-Evidenz für 1.0a7 verwendet).
- Debian-Diskussion zur NetSaint-Paketierung (1999) — https://lists.debian.org/debian-devel/1999/11/msg00316.html
- Archivindex des NetSaint-0.0.7-Pakets — https://archive.freebsd.org/ports/alpha/packages-4.6-release/All/
- Ganglia-Projekthistorie — https://ganglia.github.io/blog/archives/
- Ganglia-Core-Archiv — https://sourceforge.net/projects/ganglia/files/ganglia%20monitoring%20core/
- Ganglia-Architektur und BSD-Lizenz — https://github.com/fastly/ganglia/blob/master/ganglia.pod und https://github.com/ganglia

Diese Links bezeichnen fachliche Quellen. Sie sind keine Lizenz- oder Weitergabegenehmigung und bedeuten keine Zugehörigkeit.

## Urheberrecht und Lizenzen

Keine urheberrechtlich geschützten Listings, umfangreichen Texte, Diagramme oder charakteristischen Beispielinfrastrukturen aus Büchern übernehmen. Jede Funktion erhält eine eigene Problemstellung, ein Datenformat und Tests. Externe Programme behalten ihre eigenen Lizenzen; SASD-Dateien unterliegen der MIT-Lizenz.

## Neue Funktionen dokumentieren

Für jede Funktion sind Zweck, Profil, unabhängige Implementierung, Erstellungsdatum, Schnittstellen Dritter und bekannte Kompatibilitätstests zu erfassen. Keine historischen Tests oder angeblich zeitgenössischen Belege behaupten, wenn sie nicht nachweisbar sind.

## Big-Sister-Forschungsgrenze

Die Big-Sister-Kandidatin verwendet nur dokumentierte Prozent-Direktiven aus `bb-display.cfg` und Rechner-/Check-Zeilen aus `uxmon-net`. Die öffentliche Projektgeschichte ordnet relevante Konfigurationsarbeiten dem Profil 2000 zu; Big-Sister-Quelltext und Lizenztext werden nicht importiert. Generator und Statusadapter bleiben Offline-Kandidaten, bis eine genau benannte Big-Sister-Version auf historischem Unix ausgeführt wurde.

## R2-Grenze der CFEngine-1-Forschung

Der Kandidat verwendet die dokumentierte Form von `cfagent.conf` und `actionsequence`, weil öffentliche Referenzen diese Schnittstellen beschreiben und der Archivindex ein datiertes 1.4.0-Archiv enthält. Das Archiv wurde nicht importiert und kein originales Programm ausgeführt. Daher wird nur ein Kandidat, keine native CFEngine-1-Kompatibilität dokumentiert.

Die M5-/M6-/M7-Provisionierungswerkzeuge, Vorlagen, Fixtures und Dokumentation dieser Entwicklungslinie sind 2026 eigenständig für SASD erstellt worden. Sie verwenden etablierte Unix-Formate und nennen externe Produkte nur beschreibend; Quelltexte fremder Installer, Bootmedien oder historische Archive werden nicht weitergegeben. Native Kompatibilität wird nur bei einem aufgezeichneten Test mit genau benanntem externem Programm und genauer Umgebung behauptet.

Die NetSaint-Kandidatin C4 ist eigenständiger SASD-Code für eine begrenzte Objektkonfiguration und einen synthetischen Statusadapter. Die Quellen belegen Produktidentität 1999 und ein späteres 0.0.7-Paket, aber keine Parserabnahme der erzeugten Datei. NetSaint-Quelltext, Plugins und Daemons werden nicht weitergegeben.

Der Ganglia-Kandidat ist eigener SASD-Code für Offline-Prüfdateien von gmond/gmetad und einen begrenzten synthetischen Messwertprüfer. Ganglia 3.1.1 ist ein belegtes Zielprofil von 2008, aber keine native Abnahmeevidenz. Ganglia-Quelltext, XML-/XDR-Parser, Daemon, Netzwerktransport und RRDtool-Datenbank werden nicht weitergegeben.

Die projektübergreifende Wiederverwendungsentscheidung dokumentiert eine lesende Prüfung von SASD-Freeware-Commit `73074c6be9cef3e351aeaa28881653fdaadc9ff2`. Sie dokumentiert nur Schnittstellen und Grenzen; Freeware-Code oder ein aktueller Branch wurden nicht importiert.
