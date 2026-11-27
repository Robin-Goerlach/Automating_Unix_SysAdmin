# M1-Integrationen und spätere Adapter

English: [English version](integrations.md)

## MRTG

`bin/sasd-monitor-mrtg` erzeugt eine prüfbare Kandidatenkonfiguration mit einem Ziel je freigegebenem Rechner und Messwert. Jedes Ziel verweist auf einen lokalen `sasd-mrtg-counter`-Pfad; SNMP-Adressen, Communities und Zugangsdaten werden nicht eingebettet. `tests/m3-native.sh --require` führt ein bereitgestelltes MRTG-Binary aus und prüft HTML-/PNG-Artefakte; der dokumentierte Lauf nutzte MRTG 2.17.10 aus einem isolierten Debian-Paket.

## RRDtool

`rrd_dir` reserviert einen Bereich für Messwerte. `sasd-rrd-cycle` bleibt der ausdrückliche RRDtool-Wrapper. M1 erzeugt, aktualisiert, überschreibt oder löscht keine RRD-Datenbanken automatisch. `tests/m3-native.sh --require` prüft Create/Update/Fetch/Graph mit RRDtool 1.7.2; dies ist zeitgenössische Evidenz und keine historische Kompatibilitätsaussage.

## NetSaint, Nagios und Ganglia

M1 besitzt den kanonischen lokalen SASD-Zustand und die Historie. NetSaint gehört in das Profil 1999. Der begrenzte Nagios-Kandidat ist ein getrenntes Profil von 2002 und nutzt dasselbe Inventar sowie dieselbe Plugin-Grenze; sein Statusimporter akzeptiert nur synthetische SASD-Fixtures. Ganglia ist ein später Offline-Kandidat im Umfeld von 3.1.1 mit Inventargruppen und getrennten gmond-/gmetad-Kandidaten. Native XML-Parser, Daemon, Multicast-Transport und RRDtool-Aufnahme werden nicht implementiert. Siehe [Ganglia-Notizen](ganglia.de.md).

## CFEngine

Das R2-`sasd-site-audit` bleibt eine unabhängige lokale Prüfung. M1 importiert sein Vierfeld-Ergebnis wie jede andere lokale Beobachtung. `bin/sasd-config-cfengine1` erzeugt aus gemeinsamem Inventar und Lebenszykluszustand einen kleinen, nur warnenden CFEngine-1-Kandidaten. Deaktivierte und entfernte Hosts werden ausgelassen. Der Kandidat ist auf das Profil 1999 begrenzt und bleibt unbestätigt, bis ein originales CFEngine-1.4-Programm ausgeführt wurde. Grundlage ist die historisch dokumentierte Form mit `control`/`actionsequence`/`files`; eine native Parserprüfung wird nicht behauptet. Der Generator installiert keine Policy, startet keinen Agenten und repariert keine Systeme. CFEngine 1 und der spätere CFEngine-2-Adapter bleiben getrennte Profile.

`bin/sasd-config-cfengine2` ist der erste getrennte Adapter für ein späteres Profil. Er akzeptiert ausdrücklich benannte Kandidatenprofile 2.0 und 2.1, verwendet denselben Hostzustandsparser und erzeugt nur warnende Abschnitte `control`, `classes` und `files`. Positive und negative Offline-Tests sind vorhanden; eine native Parser- oder historische Betriebssystemabnahme von CFEngine 2 steht nicht zur Verfügung und wird nicht behauptet.

## Big Sister

Big Sister ist ein eigenes Produktprofil und kein Alias für die Big-Brother-Syntax. Die öffentliche Dokumentation beschreibt Prozent-Direktiven in `adm/bb-display.cfg` und Rechner-/Check-Regeln in `adm/uxmon-net`; `bin/sasd-config-bigsister` erzeugt aus dem gemeinsamen Inventar und Lebenszyklusmodell eine begrenzte Kandidatenausgabe für diese Schnittstellen. `bin/sasd-status-import-bigsister` wandelt synthetische Zeilen `status host.check color comment` in SASDs vierfeldrige Beobachtungseingabe um. Beide Werkzeuge arbeiten offline, lassen deaktivierte/entfernte Rechner aus, weisen doppelte Beobachtungen zurück und behaupten keine native Kompatibilität. Siehe [Big-Sister-Hinweise](../../bigsister/README.de.md).

Die Big-Brother- und Big-Sister-Adapter verwenden einen gemeinsamen,
begrenzten Parser für externe Statusdaten. Beide akzeptieren ein optionales
`status`-Präfix und ein optionales Messzeitpräfix `(epoch)` nach der Farbe;
der vollständige restliche Meldungstext bleibt erhalten. Der Produktname
kennzeichnet nur den Adapter und umgeht weder M2/M2.1-Authentifizierung noch
Enrollment. `examples/sasd-integrated-site-lab.sh` prüft Normal-, Warn-,
Kritisch-, Fehlend-, Veraltet-/Recovery-, Duplikat- und unbekannte
Rechnerfälle, ohne eines der Produkte zu starten.
