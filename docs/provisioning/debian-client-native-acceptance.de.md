# Abnahmevertrag native Debian-Basiskonfiguration (M7-D.1e)

English: [English version](debian-client-native-acceptance.md)

Status: **NUR VORBEREITUNG — natives Apply weder implementiert noch freigegeben.** Nur modernes Debian-Profil; historischer Pfad unverändert. Siehe [Client-Entwurf](debian-client.de.md).

## Diagnosewerkzeug

native-preflight.pl ist eigenständig und rein lesend. Als normaler Benutzer mit vertrauenswürdigem PATH und vertrauenswürdigen Dateibäumen ausführen. Explizites --live wählt das laufende System; --root=ABSOLUTES_VERZEICHNIS wählt einen vom echten Root getrennten Fixture-Baum und führt keine Laufzeitbefehle aus. Beide erfordern --hostname=kleingeschriebener FQDN (R2 maximal 63 Zeichen) und --address=kanonische IPv4. Sollwerte aus dem vom Betreiber ausgewählten R2-Datensatz, keine zweite Inventarautorität. Das Werkzeug validiert das Inventar nicht selbst. Es erteilt keine Schreibfreigabe, auch wenn alle beobachteten Werte stimmen.

Beispiel mit reinen Dokumentationswerten:

    perl install/debian-client/native-preflight.pl --live --hostname=node.lab.invalid --address=192.0.2.40

Nur mit einem echten, vom Betreiber freigegebenen Labornamen und Solladresse --probe-name=FQDN --probe-address=IPv4 ergänzen. Damit werden hostname -f und getent ahostsv4 explizit aktiviert, die abhängig von NSS Netzwerk-Namensabfragen auslösen können. Standardmäßig keine solche Abfrage. Der NSS-Test verlangt genau eine unterschiedliche erwartete IPv4; Dienste mit mehreren Adressen sind nicht Gegenstand dieses Vertrags. Kein direkter DNS-Nachweis: Dateien, NIS, Caches oder andere NSS-Quellen können antworten. direct-dns meldet immer NOT_RUN.

Versionierter TSV-Bericht SASD-NATIVE-PREFLIGHT-1 mit check/status/value; Steuerbytes und Prozentzeichen werden prozentkodiert. Exit 0 = Diagnose ausgegeben, NICHT Abnahme bestanden; Exit 2 = ungültiger Aufruf. UNKNOWN, OUT_OF_SCOPE, DRIFT und NOT_RUN erfordern Prüfung. Erkennung einer VM/eines Containers beweist keinen Wegwerfstatus. Keine Geheimnisse, Resolver-Dateiinhalte oder Prozesskommandozeilen erfasst; Hostnamen und IPs sind dennoch private Betriebsdaten. Befehls-stderr bleibt separat. Linux timeout begrenzt Laufzeitbefehle; fehlende Werkzeuge oder systemd-Bus bedeuten unbekannt, nicht inaktiv. Der übliche os-release-Link wird innerhalb des gewählten Baums aufgelöst; Inhalte werden geparst, nie gesourct. Nur vertrauenswürdige Fixture-Bäume einschließlich Vorfahren und Mounts, keine Sandbox für feindliche Pfade.

Resolver-Zuständigkeit ist ein Hinweis, keine Entscheidung. Erkannte Symlinks und Kommentare deuten auf systemd-resolved, NetworkManager, resolvconf oder dhclient hin. Reguläre unmarkierte resolv.conf ist UNKNOWN_REGULAR; sie kann erzeugt oder überschrieben werden. Dienstaktivität dient nur als Zusatzinformation. Verwalteten Resolver nicht ersetzen oder entlinken, Netzwerkmanager nicht deaktivieren und bei inaktivem Dienst keine statische Zuständigkeit annehmen.

## Abnahme-Gates

| Gate | Erforderlicher Nachweis | Status |
|---|---|---|
| G0 | Vollständiges make test unprivilegiert, gesamtes Archiv entpackt und getestet, exakter Commit und SHA-256 unabhängig geprüft | OFFEN |
| G1 | Betreiber bestätigt Wegwerf-Debian-VM, isoliertes Labornetz, funktionierende Konsole, nachgewiesene Snapshot-Rückkehr, keine Produktivdaten | OFFEN |
| G2 | Debian-Release, Kernel, Paket-/Toolversionen, R2-Auswahl, aktuelle Adressen und Resolver-Manager dokumentiert; Preflight und Policy geprüft | OFFEN |
| G3 | Vor nativem Schreibprogramm: expliziter Umfang, vertrauenswürdige root-eigene Eingaben, sichere Zielrechte/Links, Manager-spezifische Behandlung, exklusive Sperre, getestete Rücknahme und Reboot-Verhalten | OFFEN |
| G4 | Nach künftig freigegebenem Schreibvorgang: korrekte statische Dateien, Laufzeit-Hostname/FQDN, Soll-IPv4 vorhanden, kein Verlust des Verwaltungszugangs | OFFEN |
| G5 | Direkte DNS-A-Abfrage je erforderlichem DNS-Server und unabhängiger NSS-Test mit bekanntem Labordatensatz; falsche Antwort und unerreichbarer Server geprüft | OFFEN |
| G6 | Wiederholung, induzierter Fehler, Rücknahme, Reboot und Snapshot-Rückkehr; Ergebnisse protokolliert, kein ungeprüfter Task abgeschlossen | OFFEN |

Erstes vorgeschlagenes natives Ziel: minimale Debian-12- oder Debian-13-VM mit vom Betreiber nachgewiesener statischer Resolver-Zuständigkeit; eine reale Version auswählen und dokumentieren. Noch keine Version abgenommen. Verwaltete Resolver sind separate Integrationen, kein Rückfall auf Dateiüberschreibung. Nativer Umfang zunächst nur Identität und Resolver-Policy; keine Netzwerkkonfiguration, Dienstaktivierung, Pakete, Firewall oder zentrale Registrierung. Keine automatische Rechteerhöhung und kein natives Apply-Flag vorhanden.

## Laborablauf (lesend bis zu einem geprüften nativen Schreibprogramm)

1. Geprüften Branch-Commit beziehen, Archivintegrität gegen unabhängig vertrauenswürdigen Digest prüfen und G0 ausführen. Wegwerf-VM-Konsole und isoliertes Labornetz/VLAN statt Produktion verwenden. Snapshot-Kennung erfassen und Rückkehr auf Wegwerf-Klon nachweisen.
2. Tatsächlichen R2-Datensatz und Standort-Policy auswählen. Soll-FQDN, IPv4, DNS-Server und betreibergepflegten Testdatensatz mit genau einem A-Record erfassen, der nicht aus lokalen Hosts/NIS kommt. Keine .invalid- oder RFC-5737-Adressen als Live-Ziele.
3. Preflight und vorhandenes verify-baseline.sh protokollieren (DRIFT/UNKNOWN vor Konfiguration zu erwarten). Resolver-Linkziel, Paketzugehörigkeit, Dienststatus, DHCP-Hooks und relevante Netzwerkmanager-Konfiguration manuell erfassen. Reguläre Datei allein beweist keine Zuständigkeit. Nachweise privat halten.
4. Laufzeitauflösung und direktes DNS getrennt prüfen. Auf VM mit bereits installiertem freigegebenem DNS-Werkzeug tatsächliche Laborwerte in die folgenden lesenden Befehle einsetzen. Exitcodes, Antwortstatus, abgefragten Server, Answer-Owner/Typ und exakte Solladresse kontrollieren; erfolgreicher dig-Exit allein reicht nicht.

       getent ahostsv4 "$PROBE"
       dig +time=2 +tries=1 @"$DNS1" "$PROBE." A

   Für jeden erforderlichen DNS-Server wiederholen. Für die erste Abnahme Single-A-Record ohne CNAME nutzen. NOERROR und exakte Soll-A-Antwort verlangen; mit bekanntem negativem Datensatz und isoliertem unerreichbarem Testserver wiederholen, ohne tatsächliches Netzwerk zu stören. NSS und direktes DNS sind getrennte Nachweise. Preflight setzt keinen öffentlichen Resolver voraus und kontaktiert standardmäßig keinen.
5. Vor nativer Mutation stoppen. Künftiges natives Schreibprogramm muss G3 bestehen, danach G4–G6 von der Konsole wiederholen. fixture-apply nicht gegen / ausführen und Fixture-Schutz nicht umgehen. Snapshot zurückspielen, wenn Laufzeitverbindung oder Recovery nicht verifiziert werden können.

## Nachweise und aktuelle Testgrenzen

UTC-Zeit, exakten Commit, Archiv-Digest, VM-Snapshot-ID, Debian-/Kernel-/Toolversionen, Betreiber, Soll-/Ist-Zeilen, Befehls-Exitcodes, Original-/Soll-/Ist-Dateihashes und Recovery-Ergebnis erfassen. Rohdaten lokal privat halten, vor Weitergabe bereinigen. Native Abnahme nie aus synthetischen Fixtures oder Container ableiten. Keine Produktivfreigabe bis alle Gates geprüft und abgenommen sind.

Lokaler test-native-preflight.sh als nobody bestanden: statische Fixtures, Resolver-Hinweise, ungültige Eingabe, Nicht-Debian/mehrdeutiges Release, unsichere Links, unveränderte Quelldatei-Hashes und Nichtausführung von os-release-Inhalt. Syntaxprüfung bestanden. Separater echter lesender Smoke-Test im Debian-13-Container als nobody erfasste tatsächliche Umgebung, Abweichungen, unbekannte Dienstzustände und Container-Virtualisierung; keine explizite Namensabfrage. Live-DNS/NSS, native VM, vollständige Repository-Suite, Archiv und CI ungeprüft.
