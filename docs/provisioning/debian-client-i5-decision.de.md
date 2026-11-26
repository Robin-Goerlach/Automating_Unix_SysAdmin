# I5 — Entscheidung über main-Übernahme und natives Labor

English: [English version](debian-client-i5-decision.md)

**Status: REVIEW VORBEREITET — NICHT FREIGEGEBEN.** Dieses Dokument autorisiert weder Merge, Tag, Release noch privilegiertes Provisioning. I1 genehmigte ausschließlich den separaten Auflösungsbranch.

## 1. Exakte Eingaben und Evidenz

Gemeinsamer Vorfahr a245e2d404d8d00068e3fa8ed99964e4141ecf89; main feeb68f8fcd26835ae570b38c5f4ce68b4b8a54d; unabhängige Clientlinie f50abc84bc71a5c10ef988b12e4f87cf6af01b62; ursprüngliches Feature 01de137d88eddd71a7958b13fbc27035adfff78c. Merge 8bd0bb2224e40ac78eb83429c990303f5693fa46 besitzt beide Eltern; Compare meldet für geprüfte Korrektur a1ee2f197f8b23e47b290e95f9ee3967412e69e8 null Commits Rückstand zu beiden. Kein Historienrewrite. Pins vor Entscheidung erneut prüfen.

| CI | Exakter Umfang | Ergebnis |
|---|---|---|
| #72 / 45804862788 | Merge 8bd0bb2 | SUCCESS |
| #73 / 45805072689 | Lifecycle bc858a2 | SUCCESS |
| #74 / 45805684085 | Schreibgrenzenhärtung a358852 | FAILURE |
| #75 / 45809695510 | Korrektur literaler Ersetzungen a1ee2f1 | IN_PROGRESS  bei Review |

Vollständiges #74-Joblog 139860184193 (261 Zeilen) geprüft: zentrale Smoke-, R2-, CFEngine-, BB/BS-, Monitoring-, eingeschränkte SSH-, M4–M7-Offline-, Deployment- und Site-Labortests erfolgreich. Debian-Shellsyntax stoppte bei test-collect-native.sh:72, nicht geschlossene Zeichenkette. Lifecycle-/Distributionsschritte nicht ausgeführt. Ursache: JavaScript-Ersetzungsstring interpretierte Dollar-Quote-Syntax der grep-Ersetzung, duplizierte Skriptende; gleicher Mechanismus reduzierte doppelte Make-Dollarzeichen. Korrektur rekonstruiert Collectortest aus bekannt gutem bc858a2 mit einer literalen Ersetzung und stellt doppelte Make-Dollarzeichen wieder her. Kein beabsichtigter Guard abgeschwächt. CI #75 muss beide Fixes und tatsächliche erweiterte Lifecycletests bestätigen. Kein unabhängiger lokaler Gesamttest. Keine neuen Testerfolge aus früheren Läufen abgeleitet.

## 2. Vollständigkeitsprüfung

Vollständige rekursive Git-Trees an Vorfahr, beiden Eltern und Korrektur: 433 vereinigte Pfade, 436 Kandidatenpfade, null fehlende, null Modusänderungen. Drei Zusatzpfade: zweisprachige Reconciliation-Berichte und test-r2-lifecycle.sh. Siebzehn übernommene Pfade weichen von der ausgewählten Seite ab: Makefile, zwei Roadmaps, CI-Workflow, sechs zweisprachige Labor-/Abnahme-/Sessiondokumente, collect-native.sh, native-install.py, plan-client.pl, test-archive.sh, test-collect-native.sh, test-native-install.sh, test.sh. Dokumentierte Auflösungs-, Guard-, Test- und Übergabeänderungen, keine verlorenen Pfade. Diese Vorlage ergänzt ein zweisprachiges Entscheidungspaar und aktualisiert Roadmaps/Übergaben. Finalen veröffentlichten Tree erneut prüfen. Kein pauschales ours/theirs. Originalbranches unverändert.

## 3. Semantische Risiken und Abnahmegrenzen

| Bereich | Evidenz/Grenze | Vorgehen |
|---|---|---|
| R2-Inventarversionierung | kanonischer Parser, strengere Debianprüfungen; #73 Legacy-/Markerplan und Lifecycle erfolgreich | erhalten; finale CI prüfen |
| Lifecycle | lokaler expliziter enabled-Snapshot, unabhängiger Digest; keine zentrale Live-Revocation | nativer Blocker bis Aktualität und exklusive Administration belegt |
| Schreibguard | Prüfungen an Transaktionsgrenzen; #74 erreichte diese Tests nicht | finale CI erforderlich; keine Atomarität gegen privilegierte Fremdschreiber |
| Recovery | entzogener/geänderter Kontext blockiert Apply und CLI-Rollback; offenes Journal bleibt | Konsolen-/Snapshotrückfall erhalten; keine veraltete State-Wiedergabe; spätere Rollback-only-Freigabe getrennt |
| Gemeinsame hosts/resolv.conf | Baseline und Netzwerkgruppe getrennte Fixture-Roots | nur drei Baselineziele nativ; kein gemeinsamer nativer Writer oder Annahme finaler Resolverzuständigkeit |
| Bibliothek/Archiv | kanonischer Validator und Monitor.pm enthalten, 171 exakte Runtime-Dateien #73 geprüft | neues Release entwertet alte Referenzen; finale Archivregression erforderlich |
| Monitoring/Enrollment | Site-Labor und eingeschränkte SSH-Prüfung bestanden; synthetische Preview nie native/authentifizierte Evidenz | keine automatische Registrierung, Signatur/Import/Versand synthetischer Preview |
| Deployment | zentrale Deployment- und Clientfixturejournale getrennt | keine implizite Kette/Journalaustausch |
| Distribution | frühere saubere Extraktion/reproduzierbare Archive; #74 erweiterter Test übersprungen | zwei saubere Extraktionen, beide Prüfsummen, Manifeste/Tree und Archivgleichheit, reproducible-distribution=PASS verlangen; unabhängiger Lieferdigest getrennt |
| Historischer Umfang | M3 MRTG/RRDtool nativ und tcsh übersprungen; echte Produktdaemons, Netzboot/Produktivdeployment nicht ausgeführt | ausdrücklich nicht abgenommen, keine Kompatibilitätsbehauptung |

Nur statische Abnahme: 116 Tasks, 89 lokal, 34 begrenzte Apply-IDs (einschließlich drei experimenteller nativer Baseline), 16 Verify-only und 39 Candidate-only; 11 zentral, 16 manuell. 57 Voraussetzungskanten, 39 staged, zehn Fixturegruppen, drei statische Baseline-Dateien. Null native Abnahmen. Szenarioabdeckung, keine gemessene Zeilenabdeckung oder Beweis aller Profile. Keine physische Stromausfallevidenz.

## 4. I5-Entscheidungscheckliste

Vor Freigabe: exakte finale Kandidaten-CI grün, vollständige Logs geprüft (beide Lifecycle-Testmarker, beide Workflow-PASS-Marker, exakte Debian-Archivanzahl, Main-Labor, beide clean-extraction und Distribution-PASS, Skips ausdrücklich); Diff/Tree und beide Vorfahren geprüft; main unverändert oder Analyse wiederholen; Workflowberechtigungen und Node20-Checkoutwarnung prüfen (separate Wartung, kein Offlinefehler); keine Geheimnisse in geänderter Doku; sauberer Diff/Whitespace und zweisprachige Links. Exakten Commit, Run-/Job-IDs und Archivdigests erfassen. Auch reiner Doku-Folgecommit benötigt CI für exakten Commit. Quellarchiv-Prüfsumme ist keine unabhängige Authentizität.

Entscheidung A (gesonderte ausdrückliche Freigabe): exakt geprüften Kandidaten in unverändertes main übernehmen, beide Historien erhalten, ohne Force/Rebase/Squash. Nur Fast-Forward bei geprüfter Vorfahrenbeziehung und unveränderten Pins; sonst stoppen, kein automatischer Merge. Alte Branches behalten; PR #4 bleibt alt/konfliktbehaftet, nicht mergen oder still umstellen. Danach exakten main-Head und Main-CI prüfen; bei Fehler separat prüfen, kein automatisches destruktives Rollback. Kein V1.1-Release, keine native Autorisierung. Bis finale CI erfolgreich: HOLD.

Entscheidung B (gesonderte Freigabe): entbehrliche Debian-13-amd64-Minimal-KVM/libvirt-VM, 2 vCPU, 4 GiB, 24 GiB ext4, isoliertes Host-only-Netz, Konsole und getestete Snapshot-Rückkehr vorbereiten. [Laborentscheidung](debian-client-lab-decision.de.md) und [Laboranleitung](debian-client-lab-runbook.de.md) verwenden. G0 unabhängig geprüftes Archiv und exakte finale Testevidenz; G1 Betreiberisolation/Konsole/Snapshot; G2 Nur-Lese-Sammlung, aktueller expliziter R2-Lifecycle, statische Resolverzuständigkeit und erwartete Identität/Adresse. Zum Review stoppen. G3 nur 0010/0030/0040 nach nativen Voraussetzungen separat freigeben. G4 tatsächliche Laufzeit-/statische Prüfungen, G5 direktes DNS und unabhängiges NSS, G6 Reboot/Rollback/Restore. Alle G-Gates OFFEN; keine VM erstellt. M6 Netzboot, M7 Enrollment und V1.1 bleiben eigene Abnahmeentscheidungen.

Keine finale I5-Freigabe anfordern, bis aktuelle CI und Doku-CI bestanden. Kein main-Update, Rootstart, Force-Push, Rebase oder tatsächlicher Laborvorgang. Externe lokale Logs und unabhängig vertrauter Lieferdigest nicht verfügbar.
