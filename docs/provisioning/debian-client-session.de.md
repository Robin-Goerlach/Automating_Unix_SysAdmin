# Übergabe Debian-Client-Entwicklung

English: [English version](debian-client-session.md)

25.11.2026 — eigenständige GitHub-Entwicklung auf feature/debian-client-checklist. main und andere laufende Entwicklungssitzung nicht ändern. Basis: e5e947cf1bb536eee53089a20891f69b76648f93. Betreiber wünscht autonome Fortsetzung im Chat ohne zweite Codex-Sitzung. Lokales ../logs/LAST-SESSION.md ist hier nicht erreichbar. Dieses bereinigte Repository-Dokument dient als getrennte Übergabe; keine privaten Standortdaten oder Geheimnisse aufnehmen.

Erledigt: statische lesende Basisprüfung und negative Fixture-Tests, Integration in Test-Einstieg und Archiv. Lokaler Fixture-Test als nobody bestanden (drei ursprüngliche Dateihashes unverändert). Lokaler GitHub-Clone scheiterte an DNS-Auflösung; kein vollständiges make test und kein nativer Debian-Nachweis. Kein Live-Apply. CI-Status der vorherigen Stufe bleibt ungeklärt. Als Nächstes Policy-Validierung zentralisieren, atomare verwaltete Dateiinstallation auf Fixtures unter Erhaltung fremder hosts-Einträge implementieren, dann Abhängigkeits-Gates, Rollback und Task-Verifikation. Erst nach Abnahme expliziten nativen Labor-Apply-Pfad freigeben. Keine automatische Monitoring-Freigabe.

## M7-D.1a — Fixture-Apply-Checkpoint

Ausgangscommit: 8e0d7fa8b48a546e15a99d6a8e659d79a91295b6. Gemeinsame Policy-Validierung, ausschließlich Fixture-Apply in apply-baseline.sh, verschärfte lesende Prüfung, test-apply.sh und Paket-/Testintegration ergänzt. Die vier neuen/überarbeiteten Dateien lokal als nobody ausgeführt; test-apply.sh bestand einschließlich unveränderter Hashes nach induziertem Fehler der Abschlussprüfung. Lokale GitHub-DNS-Auflösung erneut fehlgeschlagen; vollständiges make test nicht ausgeführt. Kein natives Apply. Als Nächstes explizite Transaktionsnachweise und betreibergeprüfte Recovery ergänzen, Task-Abhängigkeiten und zentrale Inventarauswahl durchsetzen, Fixture-Pfad mit nummerierten Tasks verbinden, danach native Debian-Abnahme planen. main und parallele Codex-Sitzung unangetastet lassen. Aufbewahrte Backups wachsen pro Fixture-Apply; begrenzte Bereinigung und Crash-Recovery bleiben offen.
