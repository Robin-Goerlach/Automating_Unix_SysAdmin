# Übergabe Debian-Client-Entwicklung

English: [English version](debian-client-session.md)

25.11.2026 — eigenständige GitHub-Entwicklung auf feature/debian-client-checklist. main und andere laufende Entwicklungssitzung nicht ändern. Basis: e5e947cf1bb536eee53089a20891f69b76648f93. Betreiber wünscht autonome Fortsetzung im Chat ohne zweite Codex-Sitzung. Lokales ../logs/LAST-SESSION.md ist hier nicht erreichbar. Dieses bereinigte Repository-Dokument dient als getrennte Übergabe; keine privaten Standortdaten oder Geheimnisse aufnehmen.

Erledigt: statische lesende Basisprüfung und negative Fixture-Tests, Integration in Test-Einstieg und Archiv. Lokaler Fixture-Test als nobody bestanden (drei ursprüngliche Dateihashes unverändert). Lokaler GitHub-Clone scheiterte an DNS-Auflösung; kein vollständiges make test und kein nativer Debian-Nachweis. Kein Live-Apply. CI-Status der vorherigen Stufe bleibt ungeklärt. Als Nächstes Policy-Validierung zentralisieren, atomare verwaltete Dateiinstallation auf Fixtures unter Erhaltung fremder hosts-Einträge implementieren, dann Abhängigkeits-Gates, Rollback und Task-Verifikation. Erst nach Abnahme expliziten nativen Labor-Apply-Pfad freigeben. Keine automatische Monitoring-Freigabe.
