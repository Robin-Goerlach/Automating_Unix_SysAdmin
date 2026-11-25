# Kompatibilitäts-Evidenzmatrix

English: [English version](COMPATIBILITY.md)

Diese Tabelle erfasst Evidenz, keine Absichten. Ein Werkzeug ist nicht historisch unterstützt, nur weil seine Syntax einem älteren Unix-Befehl ähnelt.

| Umgebung oder Abhängigkeit | Derzeit vorhandene Evidenz | Zulässige Aussage | Offenes Gate |
| --- | --- | --- | --- |
| WSL2-Entwicklungsrechner, Linux 5.15.167.4-microsoft-standard-WSL2, Perl 5.36.0 | Lokales `make test`, Syntaxprüfungen und Offline-Fixtures | Zeitgenössische Offline-Entwicklungsbasis | Regressionsevidenz aktuell halten |
| GitHub-Actions-Ubuntu-Runner | Vorhandener Workflow und zuletzt dokumentierter erfolgreicher Lauf für den damals veröffentlichten Commit | Nur für diesen Runner und Commit CI-geprüft | Aktuelle Commits pushen und neuen Lauf dokumentieren |
| POSIX-Shell-Implementierungen | `sh -n` auf dem aktuellen Rechner und Offline-Shelltests | Shell-Syntax auf dem aktuellen Rechner akzeptiert | Benannte historische Shell-Matrix ausführen |
| Perl 5.004 | Keine Ausführungsevidenz; einige Werkzeuge nutzen spätere Syntax wie Defined-or und Substitutionsrückgabewerte | Nicht unterstützt oder behauptet | Abgegrenzte Teilmenge auf Perl 5.004 umschreiben oder testen |
| FreeBSD, OpenBSD, Solaris, AIX, HP-UX und andere historische Unix-Gäste | In dieser Sitzung keine native Gästevidenz | Historisch nicht bestätigt | Benannte Binaries ausführen und OS-/Toolversionen sowie Ausgabe archivieren |
| MRTG, RRDtool, CFEngine und SSH-Integrationen | Offline-Adapter und Negativtests; native Werkzeuge optional oder nicht verfügbar | Nur Offline-/Kandidatenverhalten | Exakte externe Versionen im isolierten Labor ausführen |

Die aktuelle Matrix schließt daher keine historische Supportaussage. Sie macht die negative Grenze explizit, während Netzwerkzugriff, GitHub-Authentifizierung, native Werkzeuge und historische Gäste nicht verfügbar sind.
