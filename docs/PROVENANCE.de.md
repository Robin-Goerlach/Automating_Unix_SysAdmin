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
- Nagios — https://www.nagios.org/about/history/

Diese Links bezeichnen fachliche Quellen. Sie sind keine Lizenz- oder Weitergabegenehmigung und bedeuten keine Zugehörigkeit.

## Urheberrecht und Lizenzen

Keine urheberrechtlich geschützten Listings, umfangreichen Texte, Diagramme oder charakteristischen Beispielinfrastrukturen aus Büchern übernehmen. Jede Funktion erhält eine eigene Problemstellung, ein Datenformat und Tests. Externe Programme behalten ihre eigenen Lizenzen; SASD-Dateien unterliegen der MIT-Lizenz.

## Neue Funktionen dokumentieren

Für jede Funktion sind Zweck, Profil, unabhängige Implementierung, Erstellungsdatum, Schnittstellen Dritter und bekannte Kompatibilitätstests zu erfassen. Keine historischen Tests oder angeblich zeitgenössischen Belege behaupten, wenn sie nicht nachweisbar sind.

## R2-Grenze der CFEngine-1-Forschung

Der Kandidat verwendet die dokumentierte Form von `cfagent.conf` und `actionsequence`, weil öffentliche Referenzen diese Schnittstellen beschreiben und der Archivindex ein datiertes 1.4.0-Archiv enthält. Das Archiv wurde nicht importiert und kein originales Programm ausgeführt. Daher wird nur ein Kandidat, keine native CFEngine-1-Kompatibilität dokumentiert.
