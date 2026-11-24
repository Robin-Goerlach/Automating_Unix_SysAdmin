# Entwicklungsprotokoll

English: [English version](CHANGELOG.md)

Dieses Protokoll beschreibt echte Entwicklungsarbeit und keine erfundene historische Chronologie. Zeitprofile stehen in `TIMELINE.md`.

## 2026-11-23 — unabhängige SASD-Grundlage

- Späte-1990er-Kompatibilitätsprofil und getrennte spätere Profile festgelegt.
- Lesende Unix- und `df`-Hilfsprogramme hinzugefügt.
- Eigenes vierfeldriges Statusformat und statische lokale Übersicht ergänzt.
- Golden-File-Vergleich, MRTG-kompatible Zählerausgabe und optionaler RRDtool-Aufruf ergänzt.
- Fixtures, CLI-Tests, GitHub Actions und Rechte-/Provenienzgrenzen dokumentiert.
- Offline-Prüfungen für passwd, Syslog, NTP und Cron ergänzt.
- Eigenständiges Big-Brother-Hostinventar-Format und begrenzter Linter ergänzt.

## 2026-11-23 — R2-Rechnerinventar und CFEngine-1-Kandidat

- Validiertes Vier-Rechner-TSV-Inventar und Rollenvertrag ergänzt.
- Deterministische SASD-Klassenauswahl sowie lesendes Rollen-Audit ergänzt.
- Fixtures und Negativtests für fehlerhafte und unsichere Inventardaten ergänzt.
- CFEngine-1.4.0-Quellenlage dokumentiert; native Kompatibilität bleibt offen.

## 2026-11-24 — M1 zentraler Monitoring-Server

- Begrenzte Monitoring-Konfiguration, Rollen-/Check-Wiederverwendung und sicherer Installer ergänzt.
- Lokalen Statusimport, Frischeklassifikation, begrenzte Historie und statischen HTML-Bericht ergänzt.
- Kandidatengenerierung für MRTG und explizite optionale RRDtool/MRTG-Prüfung ergänzt.
- Ausführbare Offline-Demonstration und Negativtests ergänzt.
- Getrennten Enrollment-Lifecycle dokumentiert; authentifizierter Transport bleibt M2.

## 2026-11-24 — Repository-Konsolidierung und Dokumentationspflege

- Die fertige M1-Implementierung in `main` integriert und die integrierten Feature-Branches entfernt.
- Main-first-Arbeitsablauf und leichte Prüfung der englisch/deutschen Dokumentationspaare ergänzt.
- Deutsche Handbücher ergänzt und Bedienbegriffe vereinheitlicht; Provenienz und Kompatibilitätsgrenzen bleiben erhalten.
- Sachlichen Hinweis zu möglichen CVS-/Subversion-Arbeitsweisen ergänzt, ohne deren tatsächliche Nutzung zu behaupten.
