# M7-D.7h — erste isolierte Debian-KVM-Laborinstallation: Entscheidungsvorlage

English: [English version](debian-client-lab-decision.md)

Status: **NUR VORBEREITUNG — NATIVE AUSFÜHRUNG NICHT AUTORISIERT.** Konsolidiert, ersetzt nicht, den [nativen Abnahmevertrag](debian-client-native-acceptance.de.md), die [Laboranleitung](debian-client-lab-runbook.de.md) und den [Integrationsplan](debian-client-integration-plan.de.md). Durch diese Arbeit keine VM erstellt oder aufgerufen.

## 1. Fixierter Entwicklungsstand und CI

main feeb68f8fcd26835ae570b38c5f4ce68b4b8a54d, CI #67 SUCCESS; ursprüngliches Feature 01de137d88eddd71a7958b13fbc27035adfff78c unverändert. Integrationsdokumentationscommit 3e77579a690dfe6b5eb2a83cb686d5abd38c7187, CI #69 FAILURE. Job 139827130484: Quellworkflow PASS; Archivworkflow bei fixture-apply Exit 2, invalid fixture or root execution abgebrochen. Quellinspektion: Python TemporaryDirectory kann Unterstriche erzeugen, Legacy lib/transaction.sh fixture_check erlaubt nur alphanumerische Suffixe. Log enthält tatsächliches Suffix nicht; daher begründete wahrscheinliche Ursache, keine direkte Beobachtung des Fehlerpfades. Reine Testkorrektur 278656ece5aa68300f85c21496fa729f13e7f21f nutzt /usr/bin/mktemp -d /tmp/sasd-debian-lab.XXXXXXXX, prüft alphanumerischen Pfad/Eigentümer, behält Cleanup. Kein Guard abgeschwächt, keine Runtimeänderung. [CI #70](https://github.com/Robin-Goerlach/Automating_Unix_SysAdmin/actions/runs/45804067913) bei Vorbereitung ausstehend. [CI #68](https://github.com/Robin-Goerlach/Automating_Unix_SysAdmin/actions/runs/45793947395) zuvor Quell- und entpackten Workflow bestanden (116 Tasks, 39 staged, 171 Archivdateien, drei statische Baseline-Dateien, zehn statische Gruppen, 57 wartende Kanten, Kindprozessunterbrechung/Recovery). Früheres PASS kein Nachweis für neuen Commit; M3 nativ und tcsh übersprungen. Kein nativ abgenommener Task.

PR #4 bleibt Draft/dirty; I0 für frühere fixierte Heads bewertet, I1–I5 offen. Vor autorisierter Auflösung Pins und Drei-Treevergleich aktualisieren, einschließlich Testkorrektur und dieser Dokumentation. Kein Merge/Rebase, Kandidatentree oder lokaler kombinierter Gesamttest. Alte Releases, Referenzen und Eingaben für offene Journale behalten.

## 2. Empfohlene Entscheidungen und Grenzen

| Entscheidung | Empfehlung | Freigabegrenze |
|---|---|---|
| A — Integration | Nur separaten Auflösungsbranch freigeben; beide Historien/Originalheads erhalten; I2–I5 prüfen | Ausdrückliche Freigabe; jetzt kein main-Merge |
| B — erstes Labor | Debian 13 amd64 minimal, KVM/libvirt, ein lokales ext4-Dateisystem für /etc und /var, Rolle workstation mit Profil baseline | Betreiber wählt Wegwerf-VM, bestätigt Konsole/Snapshot; keine Gast-Writes durch Vorbereitung |
| C — Nur-Lese-Sammlung | Nach geprüfter Testkorrektur und unabhängig vertrautem Release G1/G2 als normaler Benutzer in freigegebener isolierter VM sammeln; standardmäßig kein DNS | Separate Betreiberbestätigung; kein sudo, keine native Initialisierung/Apply |
| D — native Baseline | Erst nach gemeinsamen I-Gates, Lifecycle-Schutz, G0–G2 und geprüftem G3-Bereitschaftsstand | Separate ausdrückliche Entscheidung mit exaktem Release, VM-Identität, genehmigten Inputs und Recoveryplan |
| E — spätere Integration/Release | Tatsächliche native G4–G6 und getrennte M6/M7-/Produktabnahmen | Jetzt kein V1.1- oder Produktivrelease |

Vorgeschlagene VM-Größe (Planungsstandard, kein gemessenes Minimum): 2 vCPU, 4 GiB RAM, 24 GiB virtuelle Platte. Debian 12, XFS, andere Architekturen, verwalteter Resolver und separate /etc-/var-Mounts sind eigene Profile, keine Ausweichumgehungen. Isoliertes Host-only-Netz ohne Route zur Produktion, kein Produktiv-DNS, keine Produktivmounts, Geheimnisse oder Zugangsdaten. Pakete über normale OS-Installation vorbereiten: Shell, Perl, Python3, coreutils, util-linux/flock, iproute2, systemd-Werkzeuge, optional dig für späteres G5. Keine Paketinstallation durch Provisioningskripte. Betreiber weist Netzdesign, tatsächliche IP/DNS-Policy, Konsolenzugriff ohne DNS und Snapshot-Rückkehr auf Wegwerfklon nach; VM-Erkennung allein reicht nicht. Keinen Resolvermanager deaktivieren, um Test passend zu machen.

## 3. Gate-Reihenfolge und Evidenzcheckliste

| Gate | Erforderliche Evidenz vor Freigabe | Status |
|---|---|---|
| G0 | Geprüfter exakter Commit; unprivilegiertes make test, Quell-/Archivworkflow, Paket-Allowlist und unabhängig vertrauter Archiv-/Runtime-Digest; gemeinsame I2–I5-Abnahme vor nativer Mutation; relevante Skips geklärt | OFFEN |
| G1 | VM-Identität/Isolation, Debian/Kernel/Tools, ext4-Layout, sauberer Snapshot-ID und getestete Rückkehr, Konsole ohne Netz | OFFEN |
| G2 | R2-Hostauswahl, ausdrücklicher enabled-Lifecycle und Freigabekontextbindung vor nativer Mutation; Release-/Identitätsreview, tatsächlich vorhandene IPv4, unabhängig nachgewiesene Resolverzuständigkeit, Preflight/Fähigkeiten/Probelauf und geprüfte Unterschiede | OFFEN |
| G3 | Separat autorisierter Writer mit festem Umfang, genehmigtes root-eigenes Release/Inputs, Identitäts-/Metadaten-/Speicherprüfung, exklusive Administration und Rollback-/Restoreverfahren | OFFEN |
| G4 | Statischer Match und tatsächlicher Laufzeit-Hostname/FQDN/Adresse, Konsole und Managementzugriff intakt | OFFEN |
| G5 | Direktes DNS-A-Match pro freigegebenem Resolver, unabhängiges NSS-Match, negative und unerreichbare Laborfälle ohne Falscherfolg | OFFEN |
| G6 | Wiederholung/keine unbeabsichtigten Änderungen, unterbrochener Apply/Rollback, Neustart, getestete Snapshot-Rückkehr und dokumentierte Journal-/Durability-Ergebnisse | OFFEN |

Frühe unprivilegierte G1/G2-Beobachtungen auf geprüftem eigenständigem Integrationssnapshot separat genehmigbar; bei Release-/Kontextwechsel am finalen Kandidaten wiederholen. Sie schließen G0/G2 nicht und autorisieren G3 nicht. Vor jedem nativen Write alle I0–I5- und G0–G2-Bedingungen sowie ausdrückliche G3-Entscheidung prüfen. Gemeinsames Offline-PASS allein schließt keine nativen Gates.

## 4. R2-Lifecycle-Blocker

Aktueller Debian-Planer konsumiert kanonische R2-Sechsfeldliste, nicht autoritative Hostzustandsprojektion von main. Native CLI bindet hosts.tsv, roles.tsv und site.conf, nicht Lifecycle. main unterstützt enabled/disabled/removed; fehlender Default-State kann enabled bedeuten. Für natives Provisioning expliziten autoritativen Statepfad wählen und ausdrücklichen enabled-Datensatz für gewählten Host verlangen; unbekannt, disabled, removed, fehlend, ungültig oder veraltet blockieren. Main-read_host_state wiederverwenden, kein zweites Inventar. Vorgeschlagenes späteres Design: validierten Lifecycle-Input im Referenz-/Plan-/Releasekontext einfrieren und unter gleichem nativem Mutationslock vor erstem Write erneut prüfen; geänderter Lifecycle entwertet neuen Apply. Gesondert entscheiden, ob deaktivierter/entfernter Host eingeschränktes Rollback einer bereits offenen Transaktion im Originalkontext zulässt (Betreiberreview, kein neuer Apply); weder stillschweigend freigeben noch Recovery aufgeben. Tests: Legacy-/Markerinventar, fehlerhafter/nicht unterstützter/doppelter Marker, fehlender expliziter State, unbekannter/doppelter State, disabled/removed, veraltete Freigabe und Änderungen zwischen Review/Apply. Keine Umsetzung dieses Gates im Dokumentationscommit. Manuelle Prüfung allein ersetzt nativen Guard nicht; G3 blockieren bis implementiert und gemeinsame Tests bestanden.

## 5. Erste genehmigte Nur-Lese-Sitzung

Laboranleitung enthält tatsächliche Befehle. Im vertrauenswürdigen Dev-Checkout vollständigen Commit, sauberen Zustand und unprivilegiertes make test, make release-test und Debian-Paket prüfen. Archiv-SHA-256 unabhängig über getrennten vertrauenswürdigen Kanal erfassen und vor Extraktion prüfen. Kein Rootstart aus nicht vertrautem Archiv. In genehmigter VM neues privates 0700-Arbeitsverzeichnis, umask 077, geprüftes Archiv unprivilegiert entpacken. Tatsächliche R2-Laborwerte: kleingeschriebener FQDN, kanonische vorhandene IPv4, freigegebenes DNS und Suchdomain; Rolle workstation/Profil baseline, sechs Felder, leere Gruppen erlaubt. Keine .invalid- oder Dokumentationsadressen als reale Ziele. Keine Produktivdaten in Git.

    ./debian-client/collect-native.sh --live --hostname="$HOST" \
        --inventory=hosts.tsv --roles=roles.tsv --site=site.conf

Erwartete vollständige Sammlung: Exit 3, COLLECTED_NOT_AUTHORIZED. Exit 2 oder fehlender Endstatus ist unvollständig/Fehler, keine erfolgreiche Beobachtung. G2 BLOCKED bei unvollständiger unprivilegierter Fähigkeitssicht, fehlendem nativem Store oder ungeeignetem Resolver erwartet; auch REVIEW_REQUIRED keine Abnahme. G5 NOT_RUN außer bei ausdrücklich gepaarten genehmigten Probeoptionen; erste Sammlung ohne diese. Collector kopiert Inputs und erprobt auf privaten Fixturekopien, nicht echten Konfigurationsdateien. Schreibt private Reports unter /tmp; vor Reboot nach geprüftem Betreiberverfahren lokal sichern; 0700/0600 erhalten, keine Rohdaten in Git. status, scope, created-utc, commands.tsv, gates.tsv, input.sha256, plan.tsv, preflight.tsv, capabilities.tsv, observations.tsv, rehearsal/status und rehearsal/changes.tsv (soweit vorhanden) prüfen. Alter G3-Grund no-native-writer-or-authorization bedeutet OPEN/keine Autorisierung; Writer inzwischen vorhanden. Native-preflight Exit 0 niemals als Gate-PASS behandeln. Nach Sammlung stoppen und prüfen.

## 6. Spätere privilegierte Phase — hier nicht autorisiert

Nur 0010, 0030, 0040 im experimentellen statischen nativen Writer: /etc/resolv.conf, /etc/hostname, /etc/hosts. 0020 Laufzeit-DNS getrennt; 0370 finaler Resolver und alle übrigen Gruppenfixtures nicht nativ. Kein Laufzeit-Hostnamewechsel, IP-Umbau, Firewall, Paket-/Dienstaktivierung, Mount, Enrollment oder Monitoringversand. Resolver-Dateiänderung kann sofort DNS beeinflussen. Freigegebenes root-eigenes Release fest /opt/sasd/debian-client; Speicher /var/lib/sasd/provisioning mit unabhängig zugewiesener installation-id, transactions und approved (0700). Freigegebene site.conf, hosts.tsv, roles.tsv, authorization.json; Lifecycle-Bindung vor Freigabe ergänzen. Keine automatische Initialisierung. Echte Root-UID/GID, KVM/QEMU, unterstützte Dateisysteme/Flags, keine nicht unterstützten xattrs/ACLs, reguläre root-eigene Einzellinkziele, sichere Metadaten, aktuelle IPv4 und belegter statischer Resolver erforderlich. Review/Apply verlangen NetworkManager/systemd-resolved/systemd-networkd beobachtet inaktiv; unabhängiger Nachweis keines anderen Owners weiterhin nötig. Kein alternatives Root. Unabhängige Identitäts-/Fingerprint-/Release-Digests zwingend; Flags sind Betreiberattestierung, kein Nachweis. Keine Fixture-Referenzen oder Checkpoints für native Freigabe.

Nach separater Freigabe muss natives Review unabhängigen Original-/Sollbytes entsprechen und SASD-NATIVE-REFERENCE-1 STATIC_LAB_ONLY erzeugen; nur unabhängig geprüftes exaktes JSON wird Autorisierung. Vorbereitung der Apply-/Recoverybefehle bewusst bis zum tatsächlichen G3-Review zurückgestellt; hier kein Copy-and-paste-Rootmutationsbefehl. Erfolgreiches COMMITTED_STATIC ist nicht G4/G5/G6. Konsole, Snapshot und getrennte Evidenz erreichbar halten. Direkter DNS-Verifier verlangt genehmigten Server/Namen/Soll-A und expliziten Live-Modus; NSS kann über Nicht-DNS antworten, also separat prüfen. Tatsächlichen Laufzeit-Hostname nach Neustart dokumentieren, nicht nur gespeicherte Datei.

## 7. Fehler- und Recovery-Entscheidungstabelle

| Situation | Vorgehen |
|---|---|
| Drift/Unknown oder unsichere Metadaten vor Apply | Stoppen, prüfen, Guards nie abschwächen |
| APPLYING oder ROLLING_BACK | Kein neuer Apply; exaktes altes Release/Input/Referenz erhalten; einziges offenes Journal prüfen; explizit geprüftes Recovery nur wenn jedes aktuelle Ziel Original oder Soll entspricht |
| SYNC_FAILED, unbekannter Storeeintrag, fehlende Freigabe, Identitäts-/Releasekonflikt, Fremdänderung | Stoppen; Quarantäne/Journale nicht löschen; Speicherprüfung/Snapshot-Restore über Konsole |
| COMMITTED_STATIC mit anschließendem DNS-/Laufzeitfehler | Kein Closed-Journal-Rollback; genehmigten Konsolen-/Snapshot-Rückfall nutzen |
| Fixture-Checkpointabweichung | Nur Review, kein nativer Recoverynachweis |
| Nach Recovery/Neustart | Tatsächliche Evidenz neu sammeln; keine veraltete Freigabe oder Durability nur aus Endjournal ableiten |

G6 braucht Wegwerf-VM-Versuche einschließlich kontrollierter Unterbrechung nativen Apply/Rollbacks und tatsächlichem Neustart, keine Behauptung physischer Stromausfallabnahme. Originale und Vorher-/Nachher-Hashes/Modi, Journalzustände und exakten Ausgang bewahren. Snapshot-Restore setzt Gastplattenhistorie zurück; relevante Evidenz vorher getrennt sicher aufbewahren. Kein automatischer Retry nach Fehler.

## 8. Betreiber-Evidenzprotokoll (privat, keine Repositorydaten)

Pro Gate UTC-Zeit, Betreiber-/VM-Kennung, exakten geprüften Commit/CI-Run, Archiv-/Runtime-Digests, OS-/Kernel-/Toolversionen, Isolation/Konsole/Snapshot-Testausgang, gewählten Host-Lifecycle und State-Digest, Input-/Planhashes, Befehl/Exit/Status, Rohevidenzpfad/Digest, Entscheidung PASS/FAIL/BLOCKED/NOT_RUN/SKIPPED und Grund erfassen. Kein PASS aus synthetischer Beobachtung. Baseline Original-/Soll-/Ist-Metadatenhashes, Identitätsmatch (keine Roh-IDs), DNS/NSS separat, Journal-/Restoreergebnis dokumentieren. Originalreports, private Inputs, Fingerprints und Autorisierung außerhalb Git; nur geschwärzte Statuszeilen/Exitcodes/Befunde teilen. Unabhängige Freigaben von Gleichquellenhashes trennen; keine Signatur/Replay-Sicherheit behauptet.

## 9. Nächste ausdrückliche Entscheidung

Empfehlung: Nach erfolgreicher Testkorrektur-CI nur I1 freigeben (separater Auflösungskandidat, kein main-Merge, keine native Mutation); Lifecycle-Guard darin implementieren/testen, gemeinsame I2–I5 durchführen und prüfen. Parallel nur planerisch vorgeschlagene isolierte Debian-13-KVM-Baseline wählen. Tatsächliche VM-Daten erst bei genehmigter Nur-Lese-Sitzung abfragen, nicht jetzt. Betreiber behält endgültige Entscheidung über main-Integration, tatsächliche VM-Vorbereitung/Zugriff und alle nativen Operationen. Externe lokale Sessionlogs nicht verfügbar; Repositoryübergabe dokumentiert Grenze. Keine native Operation, Merge, Rebase, Release oder Gate-Schließung durchgeführt.

## I3/I4 — gemeinsame Abnahme und Härtung der Schreibgrenzen

CI #72 (45804862788, Job 139857308423, Merge 8bd0bb2) und CI #73 (45805072689, Job 139858038278, Lifecycle bc858a2) SUCCESS. Vollständige Joblogs abgerufen; integriertes Site-Labor PASS, gesonderte eingeschränkte SSH-Integration PASS, Debian-Quell-/Archivworkflow zweimal PASS, 171 exakte Laufzeitdateien, 116 Tasks, 39 staged, 57 wartende Kanten, zehn Gruppen, drei statische Baseline-Dateien, Kindprozessunterbrechung/Rollback und Checkpointabweichung/-match; #73 explizite R2-Lifecycle-Prüfungen erfolgreich. Beide sauberen Quellentpackungen PASS und Archivbytevergleich erfolgreich. M3 MRTG/RRDtool nativ, tcsh-Syntax, native Produktdaemons/Netzboot/Produktivdeployment übersprungen. CI-Warnung checkout@v4 Node20 erzwungen auf Node24; gesonderte Wartungsprüfung. Ergebnisse gelten für exakte getestete Commits, nicht für folgende Härtung.

Native Transaktionsprimitive rufen optional Kontextguard vor Erstjournal, jedem Zielschritt und terminalem Commit/Rollback auf. Native CLI übergibt ihn stets: exaktes privates (0600, Einzellink, Eigentümer/Gruppe, keine xattrs) Autorisierungs-JSON vor/nach approved_plan neu lesen; vier Inputhashes, Plan und expliziten enabled-Lifecycle gegen unabhängigen fixierten Digest unter bestehendem kooperativen Lock neu prüfen. Apply/Recovery vergleichen vollständige erwartete Zwischenzustände der Ziele statt nur aktuelles Ziel. Guard-Ablehnung vor Journal ohne neue Transaktion; danach bleibt APPLYING/ROLLING_BACK statt falschem Enderfolg. Bestehende Fixtures behalten guard=None; kein neuer nativer Task, keine Fixture-Freigabeänderung. Neue synthetische Tests prüfen tatsächlichen Teilapply nach Lifecycle-Deaktivierung, verweigertes Recovery, rein testseitiges Rollback bei identischem Kontext, Autorisierungsentzug während Rollback und privaten Autorisierungsmodus. Tests erlauben keine Wiederaktivierung/alte State-Rückspielung zur Umgehung realer Recovery.

Konservative Recoveryregel für erste VM beibehalten: entzogener/geänderter/fehlender autoritativer State oder Freigabe sperrt neuen Apply UND CLI-Recovery; Journal erhalten und separat genehmigte Konsolen-/Snapshot-Recovery, zentralen Host disabled/removed belassen. Keine automatische Ausnahme oder Wiedergabe veralteter Snapshots. Spätere unabhängige Rollback-only-Autorisierung nach nativer Laborevidenz denkbar, mit Identität, Originalrelease, Journaldigest und aktuellem autoritativem State, nie Forward-Apply. Lokale Guardprüfungen sequenziell/kooperativ, nicht atomar gegen unabhängige privilegierte Schreiber oder noch nicht importierte zentrale Änderung; Betreiber muss aktuellen State und exklusive Administration gewährleisten, G3 bleibt offen.

Collector-G3-Grund jetzt experimental-writer-not-authorized, Status weiter OPEN. make release-test bricht bei Fehlern ab, prüft beide SHA256SUMS, vergleicht Archive UND Manifeste, Manifest gegen exakten HEAD-Tree, gibt Digests und reproducible-distribution=PASS aus. Stärkt I4, authentifiziert ausgeliefertes Archiv aber nicht unabhängig. Quell-/Archiv-Runtimeanzahl unverändert (171). Neue Kandidaten-CI ausstehend; I3/I4 für bc858a2 nachgewiesen, am finalen Commit wiederholen. I5 Betreiberfreigabe/unabhängiges Vertrauen offen, alle G0–G6 offen. Keine Root-/native Operation oder main-Merge.


## I5 — aktueller Entscheidungsstand

Siehe [I5-Entscheidungsvorlage](debian-client-i5-decision.de.md). I1 genehmigt, separater Zwei-Eltern-Kandidat erstellt. CI #72/#73 erfolgreich; #74 vor Debiantests gescheitert, literale Ersetzungskorrektur a1ee2f1 veröffentlicht, #75 bei Erstprüfung ausstehend. Finale CI am exakten Commit und separate main-Freigabe erforderlich. Lifecycle-Snapshotbindung umgesetzt, native Aktualität/Zuständigkeit und G0–G6 nicht abgenommen. Keine native Operation/main-Änderung.
