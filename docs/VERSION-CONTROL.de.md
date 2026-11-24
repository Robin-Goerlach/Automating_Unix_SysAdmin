# Versionsverwaltung für Unix-Standorte

English: [English version](VERSION-CONTROL.md)

Das Repository verwendet Git; die Git-Historie ist die einzige von SASD behauptete Projekthistorie. Es werden keine CVS-/Subversion-Revisionen, `$Id$`-Werte, Veröffentlichungsdaten, Maintainer oder Migrationen erfunden.

Die Quellstruktur ist für traditionelle Unix-Änderungsverwaltung geeignet. Ein Administrator könnte Skripte, Konfigurationsdateien, Fixtures und Handbücher in einer CVS- oder Subversion-Arbeitskopie verwalten und mit dem jeweiligen Programm committen. Das ist eine mögliche Arbeitsweise, keine Behauptung, dass SASD CVS oder Subversion verwendet hat.

Für eine Arbeitskopie auf einem älteren Unix-System:

1. Quelltext, Konfigurationsvorlagen und beschreibbare Laufzeitdaten trennen.
2. Den vollständigen Diff vor einer Installation prüfen.
3. Tatsächliche Repository-Revision und Operator im Änderungsprotokoll erfassen.
4. Geheimnisse und erzeugte Statusdaten außerhalb des öffentlichen Quellbaums halten.
5. Wenn Git verfügbar ist, den Git-Commit als maßgebliche aktuelle Revision verwenden.

Keine erzeugten CVS-`$Id$`- oder Subversion-Marker und keine erfundenen historischen Metadaten in Quelldateien einfügen. Kompatibilität mit einem traditionellen Versionsverwaltungsprogramm betrifft Organisation und Verfahren, nicht Laufzeitschnittstellen oder Lizenzgrenzen.
