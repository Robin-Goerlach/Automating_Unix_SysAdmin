# M1-Zustands- und Lifecycle-Modell

English: [English version](state.md)

Gesundheitsfarbe und Enrollment-Lifecycle sind getrennt. M1 verwendet `green`, `yellow`, `red` und `purple`; `purple` bedeutet fehlend, veraltet, ungültig oder unbekannt. Die empfangene Farbe bleibt als `observed` erhalten; die Frischeprüfung kann daraus einen anderen aktuellen Zustand ableiten.

Regeln:

- Ein inventarisierter Rechner ohne Meldung erhält `observed=none`, `state=purple`.
- Eine aktuelle Meldung verwendet ihre gemeldete Farbe als Zustand.
- Eine zu alte Meldung bleibt beobachtet, wird aber als `purple` abgeleitet.
- Eine spätere aktuelle Meldung kann zu `green`, `yellow` oder `red` zurückkehren.
- Ungültige Importe werden vor jedem Schreiben des neuesten Datensatzes zurückgewiesen.

Der M2-Lifecycle lautet `pending-approval`, `approved`, `active`, `rejected` und `disabled`. M1 leitet den Gesundheitszustand weiterhin getrennt ab; eine gesperrte Registrierung wird purple angezeigt und darf keine signierten Statusdaten importieren. Der Dateiaustausch vertraut einem Hostnamen nicht ohne den genehmigten SSH-Public-Key.

Maintenance und Acknowledgement sind Betreiberannotationen unter `operations_dir`. Sie ersetzen den kanonischen Gesundheitszustand nicht. Eine gültige Annotation wird im Zyklus an die Meldung angehängt; abgelaufene Einträge werden ignoriert.

Der statische Bericht verwendet den kanonischen Zustand und zeigt eine
Alarmierungsbewertung an. Für grün gilt `CLEAR`. Bei anderen Farben hat ein
zum Zykluszeitpunkt wirksames Wartungsfenster Vorrang vor einer aktiven
Quittierung. Sonst ergeben gelb, rot und purple die Bewertung `WARNING`,
`CRITICAL` oder `UNKNOWN`. Die Bewertung dient dem Betreiberbericht.
Eine Zustellung bleibt ein eigener Integrationsschritt.

## Datensätze

Letzte Meldungen:

    receipt_epoch  host  check  observed_color  message  source

Externe Statusadapter dürfen nach der Nachricht ein fünftes Eingabefeld mit
einem geprüften Messzeitpunkt ergänzen. Dieser Zeitpunkt dient in der
unveränderten sechsfeldrigen Datei als Sortier- und Frischezeitpunkt in der
Spalte `receipt_epoch`; Vierfeld-Eingaben verwenden weiterhin den
ausdrücklichen Wert von `--received-at`. Die tatsächliche Eingangszeit wird in
diesem Format nicht dauerhaft gespeichert.

Ein Import weist Beobachtungen mehr als 300 Sekunden in der Zukunft gegenüber
der ausdrücklichen Eingangszeit, doppelte Schlüssel im Batch und das Ersetzen
einer neueren gespeicherten Beobachtung zurück. Widersprüchliche Meldungen mit
demselben Zeitpunkt werden abgewiesen; die identische Wiederholung ist sicher.
Ein Zyklus behandelt einen zukünftigen Datensatz als `purple`, damit eine
manipulierte Uhr einen ausgefallenen Rechner nicht unbegrenzt gesund hält.
`source` beschreibt nur den Adapter für die Audit-Ausgabe und ist kein
Authentifizierungs- oder Enrollment-Nachweis.

Der optionale synthetische Datenbankimport verlangt ein fünftes Feld
und lehnt Messzeiten nach der Importzeit ab. Herkunft und Geltungsbereich
sind im [Datenbankvertrag](database.de.md) beschrieben.

Abgeleiteter Zustand:

    cycle_epoch  host  check  observed_color  state  receipt_epoch  source  message

Historie:

    cycle_epoch  host  check  previous_state  new_state  source  message

Epochwerte sind UTC-Epochensekunden. `--received-at` und `--now` machen Tests deterministisch. Ein Zyklus ohne Zustandswechsel erzeugt kein neues Ereignis. Deaktivierte Inventarrechner bleiben als `purple` sichtbar; entfernte Rechner werden aus der aktiven Auswahl ausgeschlossen, ihre Lifecycle- und Monitoringhistorie bleibt jedoch erhalten.
