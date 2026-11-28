# M1 state and lifecycle model

Deutsch: [Deutsche Fassung](state.de.md)

Health color and enrollment lifecycle are separate concepts. M1 health states are `green`, `yellow`, `red`, and `purple`; `purple` means missing, stale, invalid, or otherwise unknown. A report color is retained as `observed`; freshness may derive a different current `state`.

Rules:

- An inventoried host with no report has `observed=none`, `state=purple`.
- A current report uses its reported color as state.
- A report older than `freshness` uses its reported color as observed and `purple` as state.
- A later current report can transition the state back to green, yellow, or red.
- Invalid imports are rejected before any latest record is written.

The M2 lifecycle is `pending-approval`, `approved`, `active`, `rejected`, and `disabled`. M1 still derives health state separately; a disabled enrollment is rendered purple and cannot import signed status. The file exchange does not trust a hostname without the approved SSH public key.

Maintenance and acknowledgement are operator annotations stored below `operations_dir`. They never replace the canonical health state. An unexpired annotation is added to the operator message; expired entries are ignored by the cycle.

The static report shows an alert assessment based on canonical health.
Green maps to `CLEAR`. For other colors, maintenance in effect at the
cycle time takes precedence over an active acknowledgement. Otherwise
yellow, red and purple map to `WARNING`, `CRITICAL` and `UNKNOWN`.
The assessment is visible to operators. Delivery remains a separate integration.

## Records

Latest files contain six tab-separated fields:

    receipt_epoch  host  check  observed_color  message  source

External status adapters may add a fifth input field containing a validated
measurement epoch after the message. This epoch is the observation ordering
and freshness time stored in the existing `receipt_epoch` column; ordinary
four-field input continues to use its explicit `--received-at` value. The
actual file-arrival time is not persisted in this six-field format.

An import rejects an observation more than 300 seconds ahead of its explicit
arrival time, rejects duplicate keys inside one batch, and refuses to replace
a newer stored observation. Equal-epoch conflicting observations are rejected;
repeating the identical observation is safe. A cycle treats a future-dated
record as `purple`, so a manipulated clock cannot keep a failed host healthy
forever. `source` identifies the adapter for audit text only; it is not an
authentication or enrollment decision.

The optional synthetic database import requires the fifth field and
rejects observations after the import time. See the
[database contract](database.md) for provenance and scope.

Derived state contains eight fields:

    cycle_epoch  host  check  observed_color  state  receipt_epoch  source  message

History contains seven fields:

    cycle_epoch  host  check  previous_state  new_state  source  message

Epoch values are UTC epoch seconds. The supplied `--received-at` and `--now` options make tests deterministic. Repeating a cycle without a state change does not append another event. Disabled inventory hosts remain visible as `purple`; removed hosts are excluded from active selection while their lifecycle and monitoring history remain on disk.
