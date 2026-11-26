# Debian-Client — erste Wegwerf-VM: Laboranleitung

English: [English version](debian-client-lab-runbook.md)

Status: **nur erste Bestandsaufnahme; keine native Schreibfreigabe**. Siehe [Abnahmevertrag](debian-client-native-acceptance.de.md) und [Sitzungsverlauf](debian-client-session.de.md).

## 1. Geprüften Kandidaten bauen und dokumentieren (G0)

Auf vertrauenswürdigem Entwicklungsrechner getrennten Checkout des ausdrücklich geprüften vollständigen Commit-SHA des aktuellen Integrationskandidaten verwenden, nicht den ursprünglichen veralteten Feature-Branch oder ungeprüften main-Head. Vor nativen Writes gemeinsame Branchgates und Lifecycle-Anforderungen im [Integrationsplan](debian-client-integration-plan.de.md) erfüllen. Die [Laborentscheidungsvorlage](debian-client-lab-decision.de.md) definiert gestufte Freigabegrenzen. Als normaler Benutzer ausführen. Echte Standortdateien nicht ins Repository kopieren.

    git status --short
    git rev-parse HEAD
    make test
    install/debian-client/package.sh /tmp/sasd-debian-release

Neues Ausgabeverzeichnis verwenden. Commit, Test-Exitcode und vollständiges Log, OS und Werkzeugversionen festhalten. Bei fehlgeschlagenem Pflicht-Test oder übersprungenem für native Abnahme relevantem optionalem Test G0 offen lassen. Mitgeliefertes SHA-256 prüft Transportkonsistenz, nicht Herkunft. Tatsächliche Quellen unabhängig prüfen und Archiv vor Programmausführung gegen einen über getrennten vertrauenswürdigen Kanal aufbewahrten Solldigest verifizieren. Unsignierte Prüfsumme neben Archiv ist kein unabhängiger Nachweis.

## 2. Erste VM vorbereiten (G1)

Neue minimale Debian-13-amd64-KVM/libvirt-VM auf lokalem ext4 wählen, zunächst ein Dateisystem für /etc und /var. Debian 12 und XFS bleiben separate Kandidatenprofile. Isoliertes/Host-only-Netz, keine Produktivzugangsdaten oder -Mounts, kein gemeinsamer Speicher oder Produktiv-DNS. Tatsächliche Labor-IPv4 und vorhandene Labor-DNS-Policy verwenden; für ersten statischen Test keinen verwalteten Resolver auswählen. Keinen Manager deaktivieren, nur damit eine Prüfung besteht. Gastname, genaue Debian-/Kernelversion, Hypervisor, Netzisolation und Plattenlayout festhalten. VM-Konsole ohne Netzwerk/DNS erreichbar machen. Sauberen Snapshot erstellen und Rückkehr testen, bevor Änderungen erwogen werden. VM-Erkennung allein reicht nicht.

Werkzeuge für erste Sammlung: POSIX-Shell, Perl, Python 3, coreutils, util-linux (flock), iproute2, systemd-Werkzeuge; dig nur für optionale DNS-Prüfung. Benötigte Pakete bei normaler VM-Vorbereitung installieren, nicht durch Provisioning-Scripte. Fixture-Tests nicht als root ausführen.

## 3. Erste Sammlung (G2; kein sudo)

Geprüftes Archiv und unabhängig aufbewahrten Solldigest über freigegebenen Laborweg übertragen. Vor Entpacken verifizieren. In privatem neuem Arbeitsverzeichnis als normaler Benutzer entpacken; Originalberechtigungen für späteren Release-Vergleich erhalten. Nicht über vorhandene Dateien oder als root entpacken.

    umask 077
    mkdir -m 700 "$HOME/sasd-lab-first"
    cd "$HOME/sasd-lab-first"
    sha256sum /path/to/reviewed/sasd-debian-client.tar.gz
    # Angezeigten Hash unabhängig vergleichen; bei Abweichung stoppen.
    tar --same-permissions -xzf /path/to/reviewed/sasd-debian-client.tar.gz

Im selben Verzeichnis die drei Eingaben anhand tatsächlicher separat ausgewählter Laborwerte erstellen. R2-Hostzeile hat sechs tabgetrennte Felder; leere Gruppen sind beabsichtigt. Folgendes erst nach Definition von HOST (kleingeschriebener FQDN), ADDRESS (vorhandene kanonische IPv4), DNS1 (freigegebener Laborresolver) und DOMAIN (Laborsuchdomain) verwenden:

    printf '%s\t%s\tdebian\tworkstation\t\tbaseline\n' "$HOST" "$ADDRESS" > hosts.tsv
    printf 'workstation\tsite_workstation\tmodern\troles/workstation.tsv\n' > roles.tsv
    printf 'dns1=%s\nsearch=%s\n' "$DNS1" "$DOMAIN" > site.conf

Ein Sammelkommando ausführen:

    ./debian-client/collect-native.sh --live --hostname="$HOST" \
        --inventory=hosts.tsv --roles=roles.tsv --site=site.conf

Exit 3 mit COLLECTED_NOT_AUTHORIZED ist erwartet. Ausgegebener Berichtspfad ist privat; G2 bleibt wegen unvollständiger unprivilegierter Attributsichtbarkeit oder anderer offener Bedingungen BLOCKED. Fehlender nativer Journalpfad ist in dieser ersten Phase ebenfalls erwartet. Standardmäßig keine DNS-Probes. Privilegierten Zustand nicht initialisieren und Resolver nicht ändern, nur um blockierte Ergebnisse zu beseitigen.

gates.tsv, commands.tsv, preflight.tsv, capabilities.tsv und Änderungsübersicht des Probelaufs (soweit vorhanden) prüfen. Originale privat aufbewahren. Für externe Prüfung nur relevante geschwärzte Statuszeilen und Exitcodes teilen, keine vollständigen Inventare, Originaldateien, Installations-IDs oder Fingerprints. Tatsächliche Resolver-Zuständigkeit separat prüfen, auch DHCP-Hooks und Manager-Konfiguration.

## 4. Haltepunkt vor privilegierter Phase

Experimenteller nativer Installer vorhanden, aber noch nicht ausführen. Erst G0–G2 und Fehler prüfen; genaue native Initialisierung, unabhängig geprüften root-eigenen Release und Autorisierung, Identitäts-Enrollment sowie Snapshot-/Recovery-Verfahren abstimmen. Aktuelle native CLI verwendet feste Pfade /opt/sasd/debian-client und /var/lib/sasd/provisioning und initialisiert sie nicht. Erste unprivilegierte Sammlung ist nie Freigabe. Falls VM nicht zum ersten Profil passt, Blocker melden statt Prüfungen abzuschwächen.

Spätere Abnahme muss auf tatsächlichem Wegwerf-Gast statisches Apply, Verifikation, direktes DNS/NSS, Neustart/Laufzeit-Hostname, wiederholtes Apply, unterbrochenes Apply und Recovery sowie getestete Snapshot-Rückkehr ausführen. Committed-Rollback fehlt noch; Snapshot-Rückfall zwingend. G3–G6 bis zu tatsächlichen Nachweisen offen lassen. Kein Produktiveinsatz.
