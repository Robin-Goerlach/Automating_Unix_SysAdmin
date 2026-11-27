# Technische Architektur — Profil 1999

English: [English version](ARCHITECTURE.md)

## Systemgrenze

    POSIX-df-Ausgabe / ausgewählte Referenzdateien / Zählerprobe
                         |
                 unabhängige SASD-Prüfer
              /             |              \
       disk-watch     config-drift     mrtg-counter ---> optional MRTG
                         |
                  vierfeldriger SASD-TSV
                         |
             status-store ---> Spool ---> status-board ---> statisches HTML
                                                               (kein Daemon)

    Zählerstrom ---> optional rrd-cycle ---> RRDtool-Archiv

Das R2-Rechnerinventar ergänzt einen separaten, dateibasierten Auswahlpfad:

    site/hosts.tsv + site/roles.tsv
              |                  \
      site-inventory       site-classes
              |                    |
              +----------> site-audit ---> sasd-config-drift ---> SASD-Status

M1 ergänzt einen lokalen zentralen Zustandspfad ohne Listener:

    Inventar + checks.tsv + lokale Beobachtungen
                         |
                  monitor-import
                         |
                  latest/-Datensätze
                         |
                  monitor-cycle ---> state.tsv + events.tsv
                         |
                  monitor-report ---> statisches HTML

M2 ergänzt einen Offline-Pfad für Registrierung und authentifiziertes Staging:

    Client-Bootstrap ---> enrollment.request ---> Betreiberfreigabe
          |                                      |
       SSH-Schlüssel + signierte Meldung         records/ + events.tsv
          |                                      |
          +----------> monitor-auth-import ----> M1 latest/ -> cycle -> Bericht

Das Inventar ist ein vom Administrator gepflegter TSV-Vertrag, kein DNS, keine CMDB und kein CFEngine-Parser. Rollenmanifeste wählen Referenzpfade; der bestehende Bytevergleich behält seine Semantik.

Die projektübergreifende Zuständigkeit ist in der [Architekturentscheidung zur Wiederverwendung](REUSE-ARCHITECTURE.de.md) festgelegt. Freeware liefert wiederverwendbare Diagnosen; dieses Repository besitzt Site-Identität, Lebenszyklus, Orchestrierung, historische Produktkandidaten und kontrolliertes Deployment. Die Grenze ist ein versionierter Architekturvertrag und keine verpflichtende Laufzeitabhängigkeit.

Checkpoint B ergänzt eine ausdrückliche Inventar-Schreibgrenze: `sasd-host-admin` ändert die aktive TSV nur mit `--apply` und hält deaktivierten/entfernten Zustand in einer benachbarten Zustandsdatei fest. `sasd-site-config` verarbeitet dasselbe Modell und erzeugt eine deterministische Auswahl im Staging, wobei nicht aktivierte Hosts ausgelassen werden. `sasd-site-consistency` prüft diese aktive Auswahl anschließend gegen das Monitoringmodell und weist fehlende Dienste oder Profil-/Inventarabweichungen ab. Dies sind gemeinsame Auswahlarten, noch kein nativer Produktgenerator und kein Deployment.

## Schnittstellen und Zustände

Prüferausgabe:

    host<TAB>check<TAB>color<TAB>message

- `host`: ASCII-Buchstabe/Ziffer am Anfang, danach ASCII-Buchstaben, Ziffern, Punkt, Unterstrich oder Bindestrich, höchstens 63 Zeichen.
- `check`: ASCII-Buchstabe am Anfang, danach ASCII-Buchstaben, Ziffern, Unterstrich oder Bindestrich, höchstens 32 Zeichen.
- `color`: `green`, `yellow`, `red` oder `purple`.
- `message`: eine druckbare Zeile mit höchstens 240 Bytes.

Der Statusspeicher ergänzt lokale Epochensekunden und erzeugt Dateien je Rechner/Prüfung. Alte Einträge werden als unbekannt/veraltet (`purple`) behandelt. Dies ist ein eigener SASD-Vertrag, keine BB/Hobbit/Xymon-Kompatibilität.

M1 speichert empfangene lokale Meldungen mit Empfangszeit und Quelle. Der Zyklus unterscheidet beobachtete Farbe von abgeleitetem Zustand: fehlende oder zu alte Meldungen werden `purple`, ohne eine gemeldete Farbe zu erfinden. Zustandswechsel werden begrenzt in einer TSV-Historie gespeichert.

## Betrieb und Grenzen

1. Isoliertes Arbeitsverzeichnis und reguläre Eingabedateien anlegen.
2. Lesenden Sammler ausführen und Ausgabe prüfen.
3. Lokalen Statusdatensatz schreiben oder in M1 importieren.
4. Statischen Bericht erzeugen und lokal prüfen.
5. Rollenbezogene Golden-Dateien vergleichen.
6. MRTG oder RRDtool nur nach separater Versionsprüfung einsetzen.

Es gibt keinen Listener und keinen beliebigen Remote-Befehl. M2 verwendet `ssh-keygen -Y sign/verify`, definiert keine eigene Kryptografie und prüft genehmigten Public-Key, Signatur, Rollen-/Check-Zuordnung, Ablauf, Zeitfenster und Sequenz. Ein Live-SSH-Kanal bleibt eine eigene Deployment- und Abnahmeaufgabe. `config-drift` und der R2-Audit weisen symbolische Endobjekte und symbolische Vorfahren in Manifestpfaden zurück; ein feindlicher Rename zwischen Prüfung und Lesen bleibt möglich. Nur vertrauenswürdige Verzeichnisse verwenden.

Die klassische Installation kann später `/usr/local/sasd` verwenden; der aktuelle Installer schreibt nur in ein ausdrücklich angegebenes Laborpräfix und nicht nach `/etc` oder `/usr/local`.

M5 ergänzt einen unabhängig nutzbaren Dateisystem-Archivpfad: `golden-audit` untersucht einen ausgewählten Referenzbaum; `golden-capture` erzeugt `archives/`, `manifests/` und `checksums/`; `golden-catalog --verify` prüft das aufgezeichnete Artefakt; und `golden-restore` extrahiert nur in ein neues Wegwerfverzeichnis. Das Archiv ist weder Raw-Datenträgerabbild noch bootfähige Installation. Private Identitäten, temporäre Laufzeitbäume und Pseudodateisysteme werden ausgeschlossen; Blockgeräte und Mountpoints gehören nicht zur Schnittstelle.

`sasd-config-deploy` ergänzt einen begrenzten Manifest-/Plan-/Apply-Ablauf für Review-Kandidaten in einem Wegwerfpräfix. Es ist weder ein nativer Produktparser noch ein Netzwerkverteiler.
