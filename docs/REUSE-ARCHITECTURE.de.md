# Grenze der projektübergreifenden Wiederverwendung

English: [English version](REUSE-ARCHITECTURE.md)

Diese Entscheidung hält allgemein verwendbare Unix- und Linux-
Administrationsprogramme in SASD Freeware und die Site-Orchestrierung in
Automating Unix SysAdmin. Die Repositories ergänzen sich und dürfen keine
zyklische Abhängigkeit bilden.

## Zuständigkeit von Automating Unix SysAdmin

- gemeinsames Site-Inventar, Rollen und Lebenszyklus;
- historische Produktprofile und Konfigurationsgeneratoren;
- Monitoring-Orchestrierung, Zustand, Alarmierungspolitik und Betriebsansichten;
- Installation, Provisioning, Staging, Apply-Schranken und Rollback-Nachweise;
- produktspezifische Adapter und Offline-Integrationslabore.

## Zuständigkeit von SASD Freeware

- wiederverwendbare Verwaltungsbefehle und Diagnosen;
- Ressourcen-, Dateisystem-, Netzwerk-, Dienst- und Plattformmessungen;
- Datenbankdiagnosen und produktspezifische Diagnose-Backends;
- stabile maschinenlesbare Ausgabeverträge für unabhängige Aufrufer.

Als geprüfter Referenzstand für diese Grenze dient SASD-Freeware-Commit
`73074c6be9cef3e351aeaa28881653fdaadc9ff2` mit erfolgreichen Ubuntu- und
macOS-CI-Jobs. Dies ist ein Referenzstand, keine Aufforderung, `main` zu
installieren oder externen Code zu kopieren. Vorhandene Kandidaten sind unter
anderem `fs-usage`, `fs-report`, Konto-/Gruppenprüfungen, Prozess- und
Netzwerkberichte, `tcp-check`, DNS-/NIS-/LDAP-/Mail-Probes,
Syslog-Zusammenfassungen sowie `db-probe`, `db-health`, `db-activity` und
`db-storage`.

Vor einem neuen allgemein verwendbaren Befehl wird zuerst der dokumentierte
Freeware-Vertrag geprüft. Die Wiederverwendung erfolgt über einen kleinen,
versionierten CLI-Vertrag; fehlende Funktionen, nicht unterstützte Versionen,
eingeschränkte Sichtbarkeit und ungeeignete Exit-Codes bleiben `UNKNOWN` oder
`NOT SUPPORTED`, bis eine ausdrückliche Übersetzung abgenommen ist. Ein
erfolgreicher Diagnoseprozess bedeutet nicht automatisch, dass ein
überwachtes System gesund ist. Diese Datei autorisiert keine Änderung an
Freeware.

Historische Profile dieses Repositorys bleiben unabhängig nutzbar. Sie
erhalten keine verpflichtende moderne Laufzeit und keine verpflichtende
Freeware-Abhängigkeit. Die Datenbankintegration verarbeitet daher
dokumentierte Diagnoseausgaben und unterscheidet Produkt/Version, Instanz,
Hostidentität, Quelle, Beobachtung, Messwerte, Frische und Monitoringzustand;
ein Host wird nicht als eindeutige Datenbankinstanz behandelt.
