# SASD Automating Unix SysAdmin — Anweisungen für Agents

English: [English version](AGENTS.md)

Diese Anweisungen gelten für das gesamte Repository.

## Auftrag und Abgrenzung

Entwickle eine eigenständige, zuverlässige Sammlung für Unix-Systemverwaltung mit technisch nachvollziehbaren Kompatibilitätsprofilen. Das Projekt ist keine Rekonstruktion der Infrastruktur eines Apress-Tutorials, übernimmt keinen Quelltext und behauptet kein historisch entdecktes Archiv.

Das Hauptprofil ist 1999. Funktionen aus 2002–2009 benötigen ein klar gekennzeichnetes späteres Profil. CFEngine 1 gehört zum Profil 1999; CFEngine 2, Nagios und buchbezogene Komponenten von 2009 nicht. Siehe `docs/TIMELINE.md`.

## Quellen und Rechte

- Bücher dienen nur als Quellen für allgemeine Ideen, Architekturfragen und Themenabdeckung. Namen, Datenformate, Algorithmen, Fixtures und Texte werden unabhängig entworfen.
- Hinweise und Lizenztexte Dritter bleiben erhalten. Keine Buchlisten, kein proprietärer Big-Brother-Code und keine Konfiguration unter der MIT-Lizenz dieses Projekts.
- `docs/BOOK-MAP.md` bleibt eine Themenübersicht und wird nicht zu einer kapitelweisen Quelltextabschrift.
- Produktnamen Dritter werden beschreibend verwendet und bedeuten keine Empfehlung oder Zugehörigkeit.

## Entwicklung

- Bevorzuge POSIX-sh, awk, sed und für die Profile geeignete Perl-Core-Module.
- Keine verpflichtende Abhängigkeit von Node, Python, Docker, systemd, Webdiensten oder einer neuen Laufzeit im kompatiblen Ausführungspfad.
- Verwende zeilenorientierte Textdateien und klare Schnittstellen; unabhängige Werkzeuge dürfen ohne zentrales Framework betrieben werden.
- Erkläre Vertrauensgrenzen und Fehler. Weise unsichere Bezeichner und Pfadtraversierung zurück und führe keine untrusted Eingaben als Shell-Code aus.
- Administrative Änderungen benötigen eine ausdrückliche Operation und bleiben bis zu einer dokumentierten Abnahme auf Wegwerf-Testsysteme begrenzt.
- Neue CFEngine-, MRTG- und RRD-Beispiele sind unbestätigte Vorlagen, bis die jeweilige Version getestet wurde. Version und Betriebssystem sind vor Kompatibilitätsaussagen zu erfassen.
- Ein Test auf einem aktuellen CI-System beweist keine Funktion auf einem historischen Unix oder mit Perl 5.004.

## Arbeitsablauf

1. Lokales `main` mit `git pull --ff-only` aktualisieren und einen sauberen Arbeitsbaum prüfen.
2. README, Architektur, Roadmap, Sicherheitsdokument, betroffene Quellen und Tests lesen.
3. Kompatibilitätsprofil und eigenständige Aufgabe bestimmen.
4. Das kleinste begrenzte Werkzeug oder die kleinste Integration implementieren und Fixtures sowie Negativtests ergänzen.
5. `make test` ausführen; optionale Integrationen getrennt erfassen.
6. Englische und deutsche technische Dokumentation gemeinsam ändern und den Dokumentationspaar-Test ausführen.
7. Diff prüfen, gewöhnliche Änderungen direkt auf `main` committen, pushen und GitHub Actions prüfen. Temporäre Branches sind für riskante oder separat zu prüfende Arbeiten vorgesehen.
8. Das getrennte Repository `SASD-Sysadmin/freeware` nicht ungefragt ändern.
9. Keine Testergebnisse, Veröffentlichungsdaten, Historie oder Provenienz erfinden.

## Dokumentationspflege

Englische Markdown-Dateien sind kanonisch; deutsche Fassungen tragen den Suffix `.de.md`. Jede wesentliche Änderung an einer englischen technischen Dokumentation aktualisiert die deutsche Fassung im selben Commit. `make test` prüft Paare und offensichtliche relative Links, beweist aber nicht die Qualität einer Übersetzung.

## Sitzungsabschluss und Kontextübergabe

- Zu Beginn jeder Entwicklungssitzung `../logs/LAST-SESSION.md` und bei Bedarf das darin referenzierte vollständige Archiv lesen.
- Zu Beginn jeder Entwicklungssitzung zusätzlich den vollständigen `../logs/MASTER-ASSIGNMENT.md` lesen. Dieser enthält den dauerhaften strategischen und technischen Auftrag; er darf nicht durch eine verkürzte Sitzungszusammenfassung ersetzt oder eigenständig verändert werden.
- Am Ende jedes Entwicklungsauftrags ein vollständiges UTC-datiertes Sitzungsarchiv in `../logs` erstellen, auch bei teilweise erledigter Arbeit oder fehlgeschlagenem Push, CI-Lauf, Netzwerkzugriff oder technischen Gates.
- `../logs/LAST-SESSION.md` erst aktualisieren, wenn das vollständige Archiv existiert und lesbar ist. Die Übergabe muss den tatsächlichen Repository-, Test-, Commit-, Remote- und CI-Zustand, Blocker und den nächsten sicheren Schritt nennen.
- Vor einer Empfehlung zu `/new` Archiv und Übergabe vervollständigen und verifizieren. Nach einer Unterbrechung zuerst prüfen, ob der vorherige Entwicklungsstand dokumentiert wurde, und fehlende Dokumentation bei nächster Gelegenheit nachholen.
- Keine Archive für gewöhnliche Zwischenmeldungen erzeugen. Niemals Geheimnisse, Tokens, private Schlüssel oder Produktionsdaten archivieren und unbestätigte Tests, Pushes oder CI nicht als erfolgreich darstellen.

Die Sitzungsarchivierung ist Bestandteil der Definition of Done und keine optionale Berichtspflicht.

## Fertigstellung

Ein neues Werkzeug benötigt Zweck, Ein-/Ausgabe, sichere Fehlerbehandlung, ein Offline-Fixture und mindestens einen Negativtest. Eine Integration Dritter benötigt eine Versionsmatrix und direkte Abnahmeevidenz, bevor sie als historische Funktion beschrieben wird. Geplante Aufgaben sind keine erledigten Aufgaben.
