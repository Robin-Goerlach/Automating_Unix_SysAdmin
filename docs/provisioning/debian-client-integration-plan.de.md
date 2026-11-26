# M7-D.7g — Branch-Integrations- und Abnahmeplan

English: [English version](debian-client-integration-plan.md)

Status: **VORBEREITET — NICHT GEMERGT — GEMEINSAME ABNAHME OFFEN.** Fixierte Nur-Lese-Bewertung und Auflösungsvorschlag, kein aufgelöster Merge-Tree, keine Autorisierung oder V1.1-Releaseentscheidung. [Nativer Abnahmevertrag](debian-client-native-acceptance.de.md) und [Clientdesign](debian-client.de.md) bleiben maßgeblich.

## 1. Geprüfte Eingaben und Evidenz

| Rolle | Exakter Git-Commit | Ergebnis |
|---|---|---|
| Gemeinsamer Vorfahr | a245e2d404d8d00068e3fa8ed99964e4141ecf89 | Merge-Base aus Compare-API |
| main | feeb68f8fcd26835ae570b38c5f4ce68b4b8a54d | [CI #67](https://github.com/Robin-Goerlach/Automating_Unix_SysAdmin/actions/runs/45793524991) SUCCESS |
| integration/debian-client-checklist vor Dokumentation | f9ff5530614eaa58153b83e9b8e8aead07987a66 | [CI #68](https://github.com/Robin-Goerlach/Automating_Unix_SysAdmin/actions/runs/45793947395) SUCCESS |
| Ursprünglicher Feature-Branch | 01de137d88eddd71a7958b13fbc27035adfff78c | unverändert, erhalten |

Beide Joblogs abgerufen. Main-Job 139818242136 meldet SASD integrated offline site laboratory PASS; native M3-MRTG/RRDtool sowie native Daemons/Netzboot/Produktionsdeployment übersprungen. Integrationsjob 139819680319 meldet SASD-OFFLINE-WORKFLOW-TEST-1 zweimal PASS (Quellbaum und entpacktes Archiv), 116 Tasks, 39 staged, drei statische Baseline-Dateien, zehn Gruppenbeobachtungen, 57 wartende Kanten, Teilschreibabbruch im Kindprozess, ROLLED_BACK, alter Checkpoint EVIDENCE_CHANGED, neuer CHECKPOINT_MATCH_REVIEW_ONLY. Archivintegration 171 exakte Dateien; M3 nativ und tcsh-Syntax übersprungen. Native Verifikation NOT_VERIFIED, Ausführung NOT_AUTHORIZED. Keine Hochstufung unabhängiger Erfolge zur gemeinsamen Abnahme.

GitHub-Compare: Integration 52 Commits voraus, sieben zurück. Rekursive Trees vollständig. Blobpfade, Hashes und Modi gegen Vorfahren verglichen: main 55 geänderte Pfade (36 geändert, 19 hinzugefügt), Integration 231; keine Löschungen auf beiden Seiten. Drei Pfade unterschiedlich auf beiden Seiten geändert, keine identischen Überlappungen. Vereinigung 283 (52 nur main, 228 nur Integration, drei Überlappungen). PR #4 offen/Draft, mergeable false, dirty. PR-Basisfeld zeigte alten gemeinsamen Vorfahren; tatsächliche Branch-Heads und Compare-API verwenden, nicht veraltetes PR-Basisfeld. [PR #4](https://github.com/Robin-Goerlach/Automating_Unix_SysAdmin/pull/4).

## 2. Beide Arbeitsstände vollständig erhalten

Sieben Main-Commits in Reihenfolge:

- 4a009a0: gemeinsame Sitevalidierung und CFEngine-1-Adapter.
- 0d48c3d: gemeinsamer Hostzustandsparser und CFEngine-2-Adapter.
- 2a35193: Inventarversionierung und Big-Brother-Kandidat.
- 76ea07b: Big Sister und Härtung der Inventarmigration.
- 08f5604: Checkpoint-Status.
- a5dd317: integriertes Offline-Monitoringlabor.
- feeb68f: kontrollierte Konfigurationsbereitstellung.

Alle Main-exklusiven Änderungen erhalten, einschließlich Lesbarkeitsregeln AGENTS.md/AGENTS.de.md, gemeinsamer Perl-Bibliothek, Inventarmigration, Host-Lifecycle, getrennter Produktadapter, Dokumentation, Deployment, Tests und integriertem Labor. Alle Integration-exklusiven Änderungen erhalten, einschließlich unabhängiger CI-Push-Trigger, vollständigem Debian-Teilbaum, experimentellen nativen Baseline-Schutzmaßnahmen, Quell-/Archivtests, zweisprachigem Design und Sessionhistorie. Keine Domäne überschreibt die andere. Keine alten Validator-/Modulkopien wiederherstellen oder main durch Integrationstree ersetzen. Ursprünglichen Feature-Branch nicht zusätzlich mergen.

## 3. Überlappungsprüfung und konkreter Auflösungsvorschlag

Vorfahr und beide vollständigen Versionen der drei Pfade verglichen. Zeilennummern beziehen sich auf Vorfahren (Einfügung vor Zeile bzw. am Ende). Textuelle Änderungsanalyse, kein ausgeführter Git-Merge oder nachgewiesene Konfliktmarkerliste.

| Pfad | main-Änderungen | Integrationsänderungen | Vorgeschlagene Auflösung |
|---|---|---|---|
| Makefile | Zeile 2, Einfügungen vor 8/9/19/21, Ersetzung 24–25 | Einfügung vor 19 | Vollständiges Main-Makefile, Debian-Test einmal nach integriertem Site-Lab-Beispiel und vor deployment-test-Target |
| docs/ROADMAP.md | Einfügung vor 17; Ersetzungen 52 und 112 | M7-D vor 174 (Ende) | Main-Checkpoint A–F und Produktfortschritte erhalten, abgestimmten M7-D-Block anhängen |
| docs/ROADMAP.de.md | Einfügung vor 17; Ersetzungen 25 und 91; Anhang vor 142 (Ende) | M7-D vor 142 (Ende) | Main-Abschlussabsatz zu Deployment erhalten, parallelen M7-D-Block anhängen |

Makefile-Einfügestelle und deutsches Roadmap-Ende sind tatsächlich überlappende Editierstellen; englische Roadmap im Zeilenvergleich disjunkt. Git meldet dirty; kein Merge versucht, exakte Konflikthunks ungetestet. Kein pauschales ours/theirs oder Strategieoption.

### Vorgeschlagener Makefile-Testvertrag

Mit exaktem Main-Makefile beginnen. .PHONY-Targets test, syntax, release-test, site-test, integrated-site-lab, deployment-test erhalten. Beide vorhandenen Syntaxschleifen mit neuen Produkt-/Deploymentkommandos erhalten. Alle Main-Testzeilen in Reihenfolge behalten. Genau eine mit Tab eingerückte Zeile direkt nach "sh examples/sasd-integrated-site-lab.sh" innerhalb test einfügen (nicht im dedizierten Lab-Target):

    sh install/debian-client/test.sh

Damit bleiben 21 Main-Recipe-Kommandos (inklusive docs-pairs) plus eine Debian-Suite nach Syntaxvoraussetzung erhalten. Debian-Suite ruft eigene Shellsyntax und 46 Komponenten-/Zusammenbautestskripte auf, darunter Quell- und Archivablauf. Debian-Test nicht doppeln oder Main-Test/Syntax durch ältere Fassung ersetzen. release-test erhalten; Debian-Archivprüfung und entpackte Quelltests zusätzlich durchführen, da repositoryweites release --test nur Teilmenge testet. Integrationsworkflow .github/workflows/test.yml erhalten (main und Integration als Push-Branches, pull_request, contents: read, make test); Main-Kopie hat keinen Integrationstrigger. Separater Auflösungsbranch braucht geprüften Trigger oder gleichwertigen expliziten lokalen Test; konfliktbehafteter PR löst nicht zwingend CI aus.

### Vorgeschlagener gemeinsamer M7-D-Roadmapblock (Deutsch)

- Moderne Debian-Checkliste: 116 Originalmarker, 89 lokale Kandidaten, 11 zentral, 16 manuell; 57 Abhängigkeiten. 34 begrenzte Apply-IDs (drei experimentelle Baseline, 23 Konfigurationsfixtures, vier Zustandsmodelle, vier Policy-Datensätze), 16 Verify-only, 39 Candidate-only. Null native Abnahmen.
- R2 bleibt einziges Inventar. Versioniertes gemeinsames Inventar, Lifecycle und Produktmodell aus main nutzen; strengere Debian-FQDN-/kanonische IPv4-Prüfung erhalten. Lifecyclebewusstes Provisioning und zentrale Registrierung/Entfernung noch nicht implementiert.
- Offline-Review, Transaktion, Recovery, Evidenz, Orchestrierung und Checkpoint-Ablauf auf Integrationsbranch geprüft. Statische Beobachtungen erfüllen keine nativen Voraussetzungen. Gemeinsame Branchabnahme offen.
- Verbleibende sichere Backends, Zuständigkeiten/Reihenfolge gemeinsamer Dateien, echte Laufzeitprüfung, ausdrückliche Enrollmentfreigabe und Wegwerf-VM G0–G6 vervollständigen; historische Produkt- und V1.1-Gates unverändert.
- Siehe [Clientdesign](debian-client.de.md), [nativen Vertrag](debian-client-native-acceptance.de.md) und diesen Integrationsplan.

Main-Checkpoint B/F und frühere Checklistenformulierungen abgleichen, nicht blind als aktuellen Stand übernehmen: begrenztes kontrolliertes Deployment offline umgesetzt (kein natives Deployment/keine vollständige Orchestrierung); Produktgeneratoren/Migration umgesetzt, weitere Deployment-Orchestrierung offen. Beide Sprachen gleich behandeln; E soll modernes Debian-Offline-Ergebnis nennen, ohne native Netzboot-/Postinstallabnahme zu behaupten. A/C/D und übrige Planungen erhalten. Kanonische Roadmaps in diesem Vorbereitungscommit nicht umschreiben.

## 4. Semantische Schnittstellenrisiken (auch ohne Textkonflikt)

| Vertrag | Quellbeobachtung | Verpflichtende gemeinsame Abnahme |
|---|---|---|
| R2-Validator | main delegiert sasd-site-inventory an SASD::Monitor read_inventory; sechs Felder und Hostabfrage erhalten; Legacy und SASD-SITE-INVENTORY-1 | Exakter Planoutput für gleiche gültige Legacy-/Markerinventare; ungültige/falsch platzierte/doppelte Marker, doppelte Hosts/Adressen, unbekannte Rolle, Profilkonflikt abgelehnt |
| Debian-spezifische Grenzen | plan-client.pl lehnt unabhängig doppelte Hosts ohne Beachtung der Großschreibung, nichtkanonische IPv4 und Nicht-Debian-Auswahl ab | Grenzen erhalten, auch wenn Main-Validator toleranter |
| Host-Lifecycle | main read_host_state enabled/disabled/removed; Debian-Planer konsumiert --list ohne Lifecycle-Eingabe | Vor nativem Dispatch autoritativen Statepfad und Fail-closed-Policy ausdrücklich entscheiden; disabled/removed, unbekannter Zustand, fehlender expliziter State und veraltete Freigabe testen. Nicht aus sechs Feldern enabled ableiten. Kein zweites Inventar/Produktionswrite |
| Archivabhängigkeiten | package.sh kopiert aktuelle kanonische bin/sasd-site-inventory und lib/SASD/Monitor.pm; Main-Validator FindBin ../lib; Archivpfade lib/sasd-site-inventory und lib/SASD/Monitor.pm passen laut Inspektion | Bytes/Modi kombinierter Versionen vergleichen, ohne umgebenden Checkout testen, fehlende Bibliothek ablehnen, kanonischer Planhash bei gleichem Input gleich; keinen alten Code vendorn |
| Releaseidentität | lab-install.release_digest enthält beide kanonischen Abhängigkeiten; Austausch ändert Release auch ohne Debian-Dateiänderung | Frische Fixture-Referenzen, Manifeste/Evidenz und Checkpoints mit neuem Release in sauberen Roots; altes Archiv/Input/Referenz für offene Journale erhalten. Alte Referenz nicht patchen/neu signieren |
| Monitoring | main ergänzt externe Messzeit-/Frischevalidierung und erhält Vierfeldformat; Debian nutzt read_checks/applicable_checks/validate_status | M1/M2, BB/BS-Adapter und Previewtests; Rolle, ungültige/doppelte/veraltete/widersprüchliche Beobachtungen prüfen; synthetische Previews NIE importieren, signieren, senden oder freigeben |
| Zentrales Deploy vs. Client | Main sasd-config-deploy stellt host-services/BB/BS/CFEngine in Wegwerfpräfix mit eigenem Manifest/Plan/Backup bereit; Debian andere Journale/Roots | Getrennte Namespaces, keine automatische Kette/Journalaustausch; Drift, Rollback, keine unbeabsichtigten Writes in beiden prüfen; spätere Komposition mit expliziter Zuständigkeit/Reihenfolge |
| Gemeinsame Ziele | Baseline und Network modellieren hosts/resolv.conf | Noch kein gemeinsamer nativer Writer. Zuständigkeit/Reihenfolge, Resolvermanager, Übergabeevidenz vor nativer Anwendung |
| Historische/moderne Pfade | Main-AGENTS erhält 1999/spätere Profile; Python/Linux nur modernes Debian | Historische Einstiegspunkte POSIX/Perl, kein obligatorisches Python/systemd historisch |

Keine Sitepolicy, Lifecycle-Daten, echten Paketquellen, DNS-Registrierung, Monitoringchecks oder Enrollmentfreigaben durch dieses Dokument geändert. Standardkatalog der Hardwarechecks vor realer Nutzung weiterhin gesondert prüfen.

## 5. Spätere autorisierte Auflösung

Folgende Befehle sind NUR-LESE-Prüfbeispiele, keine jetzt auszuführende Merge-Anleitung. Vertrauenswürdiger Checkout mit allen Objekten, keine Produktionszugangsdaten, unprivilegiert, sauberer Worktree. Pins erneut prüfen; bei Fortschritt eines Branches Analyse aktualisieren.

    BASE=a245e2d404d8d00068e3fa8ed99964e4141ecf89
    MAIN=feeb68f8fcd26835ae570b38c5f4ce68b4b8a54d
    INTEGRATION=f9ff5530614eaa58153b83e9b8e8aead07987a66
    git merge-base "$MAIN" "$INTEGRATION"
    git diff --name-status "$BASE" "$MAIN"
    git diff --name-status "$BASE" "$INTEGRATION"
    git diff "$BASE" "$MAIN" -- Makefile docs/ROADMAP.md docs/ROADMAP.de.md
    git diff "$BASE" "$INTEGRATION" -- Makefile docs/ROADMAP.md docs/ROADMAP.de.md

Erst nach ausdrücklicher Betreiberfreigabe: isolierten Auflösungsbranch/Worktree vom fixierten aktuellen main anlegen, Historie beider Eltern erhalten, nur geprüfte Überlappungen und notwendige semantische Anpassungen auflösen, jede Ausnahme dokumentieren. main/ursprüngliches Feature nicht pushen. Kein Force-Push, Rebase oder Historienrewrite; kein Squash mit Verlust erforderlicher Historie. Ändern sich Remote-Heads, stoppen/neu bewerten. Für späteren Kandidaten CANDIDATE beide Vorfahrenbeziehungen mit git merge-base --is-ancestor prüfen, vollständige Trees/Pfadmodi vergleichen, jeden einseitig geänderten Pfad exakt der Seite entsprechend verlangen außer gesondert geprüften Änderungen. Alle 283 geänderten Pfade dieser Basis plus spätere Dokucommits prüfen; keine fehlenden Pfade, ungewollten Löschungen, Geheimniskopien, Modusdrift oder zusätzlichen ungeprüften Änderungen. Beide ursprünglichen Heads erreichbar halten. diff --check und vollständigen kombinierten Diff prüfen. Hier kein Kandidat erzeugt.

## 6. Abnahmegates und Übergabe

| Gate | Erforderliche Evidenz | Aktueller Status |
|---|---|---|
| I0 fixierter Vergleich | Vollständige Heads, Vorfahr, Pfad-/Hash-/Modusvereinigung, separate CI und Logs | PASS für fixierte Eingaben |
| I1 Betreiberfreigabe | Ausdrückliche Freigabe nur zur Auflösung, aktuelle Pins, Brancherhalt | OFFEN |
| I2 geprüfter Kandidat | Beide Historien, Treevereinigung/Ausnahmen, zweisprachige Roadmap, exakte gemeinsame Verträge | OFFEN |
| I3 gemeinsame Offline-Abnahme | Vollständiges unprivilegiertes make test auf exaktem Kandidaten, Main-Labor und Debian-Quell-/Archivablauf PASS, Skips dokumentiert | OFFEN |
| I4 Distribution | make release-test, deterministische Quellarchive, Debian-Allowlist und saubere Extraktion, unabhängig erwarteter SHA-256 erfasst | OFFEN |
| I5 Release-Review | Kombinierte CI grün auf exaktem Kandidat, keine verlorenen Regressionen, Grenzen dokumentiert, Betreiber entscheidet PR/main-Integration | OFFEN |
| Native G0–G6 | Nativer Vertrag, Wegwerf-Debian-VM, Konsole/Snapshot, Nur-Lese-Preflight, separat freigegebene Baseline, DNS/NSS, Reboot/Recovery | ALLE OFFEN |

Nach I1/I2 unprivilegiert make test, make site-test, make deployment-test, make integrated-site-lab, sh install/debian-client/test.sh, sh install/debian-client/test-offline-workflow.sh und make release-test ausführen. Commit, OS, Versionen, UID, Befehle, Exitcodes und Loghashes erfassen; redundante Einzeltests zur Diagnose unterscheiden. Im entpackten Quellarchiv (ohne .git) passende Komponententests direkt, nicht Git-abhängigen docs-pairs-Test starten; Debian-Archiv separat über tatsächliches test-archive.sh prüfen. Erwartet 116 Zeilen, 39 staged, 171 Debian-Runtime-Dateien außer geprüft geänderter Vertrag, zehn Gruppen, drei Baseline-Dateien, 57 wartende Kanten, echter Kindprozessabbruch/Recovery und Checkpointabweichung/-übereinstimmung. Neue R2-/Lifecycle-Regressionen vor nativer Nutzung verpflichtend. Fehlendes tcsh, native MRTG/RRDtool- oder Produktdaemonprüfungen SKIPPED/NOT TESTED statt PASS; relevante fehlende Voraussetzungen blockieren native Abnahme, nicht durch Offline-CI abgedeckt. Keine nativen Änderungen, kein authentifizierter Fixture-Statusimport, keine automatische native Abhängigkeitspromotion.

I0 ist nur Vorbereitung. Kein Merge/Rebase, Kandidatenbuild, lokaler kombinierter Gesamttest, nativer Test oder tatsächliche Konfliktauflösung durchgeführt. Direkter lokaler Git-Zugriff zuvor wegen DNS nicht verfügbar; externe Betreiberlogs über diese Schnittstelle unerreichbar. Alte Releasereferenzen für Recovery erhalten. Nächster D.7h: Nur-Lese-Laborcheckliste/Evidenz und Entscheidungsvorlage vorbereiten; I1–I5 und alle G-Gates bleiben ausdrücklich freigabepflichtig. V1.0 bleibt unverändert; kein V1.1-Release.
