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

## Datensätze

Letzte Meldungen:

    receipt_epoch  host  check  observed_color  message  source

Abgeleiteter Zustand:

    cycle_epoch  host  check  observed_color  state  receipt_epoch  source  message

Historie:

    cycle_epoch  host  check  previous_state  new_state  source  message

Epochwerte sind UTC-Epochensekunden. `--received-at` und `--now` machen Tests deterministisch. Ein Zyklus ohne Zustandswechsel erzeugt kein neues Ereignis.
