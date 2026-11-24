# Kompatibilitätsprofile

English: [English version](TIMELINE.md)

Dieses Dokument trennt die von einer Funktion dargestellte Zielzeit von ihrem tatsächlichen Erstellungsdatum. Die Entwicklung begann 2026; Git-Commits werden nicht zurückdatiert.

| Profil | Zeitraum | Verfügbare Technik | Geeignete SASD-Arbeit | Bis später ausgeschlossen |
| --- | --- | --- | --- | --- |
| P0 | 1985–1988 | Bourne-Shell, awk, sed, cron, syslog; Perl ab 1987 | Log-, passwd-, Backup- und Systemberichte | CFEngine, MRTG, Big Brother, RRD |
| P1 | 1989–1994 | Perl 4/5, frühes SSH und CFEngine 1 | Datei- und Policyprüfungen, CFEngine 1 | CFEngine 2, MRTG vor 1995 |
| P2 | 1995–1997 | MRTG 1, Big Brother, CFEngine 1 | SNMP/MRTG-Ziele, einfache Überwachung | RRDtool 1.0, Nagios |
| P3 | 1998–1999 | RRDtool-Entwicklung, NetSaint | RRD-Historie, Statusboard, NetSaint-Adapter | CFEngine 2, Nagios-Name |
| P4 | 2002–2004 | CFEngine 2, Nagios | CFEngine-2-Master, Checks, SSH-Regeln | 2009-Verfahren als 1999 darstellen |
| P5 | 2005–2009 | FAI/Kickstart/JumpStart, CFEngine 2, Ganglia/NRPE | Multi-OS-Bootstrap und Reporting | rückwirkende Behauptungen |

## Quellen und Einschränkungen

Die englische Fassung verzeichnet die Quellen zu CFEngine, MRTG, Big Brother, RRD und NetSaint. Diese Datierungen sind keine Behauptung, dass jedes Programm auf jedem Zielsystem verfügbar war. Insbesondere ist moderne CFEngine-3-Syntax nicht austauschbar mit früheren Versionen.

**Profilbezogen** bedeutet, dass eine zeitlich passende Schnittstelle ausgewählt wurde. **Historisch geprüft** bedeutet einen erfolgreichen Test auf einem genau benannten Originalsystem mit dokumentiertem Programm und Ergebnis. CI ist nur zeitgenössische Entwicklungsevidenz.

Für ältere Unix-Varianten sind isolierte KVM-/QEMU-Gäste mit Host-only-Netz zu verwenden. Alte Dienste nicht an ein normales Netz anschließen.
