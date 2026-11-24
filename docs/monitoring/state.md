# M1 state and lifecycle model

Health color and enrollment lifecycle are separate concepts. M1 health states are `green`, `yellow`, `red`, and `purple`; `purple` means missing, stale, invalid, or otherwise unknown. A report color is retained as `observed`; freshness may derive a different current `state`.

Rules:

- An inventoried host with no report has `observed=none`, `state=purple`.
- A current report uses its reported color as state.
- A report older than `freshness` uses its reported color as observed and `purple` as state.
- A later current report can transition the state back to green, yellow, or red.
- Invalid imports are rejected before any latest record is written.

The local lifecycle for future enrollment is `unknown`, `enrollment-requested`, `pending-approval`, `approved`, `active`, `stale`, and `disabled`. M1 only implements the inventory and local import portions; it does not trust a hostname submitted over a network.

## Records

Latest files contain six tab-separated fields:

    receipt_epoch  host  check  observed_color  message  source

Derived state contains eight fields:

    cycle_epoch  host  check  observed_color  state  receipt_epoch  source  message

History contains seven fields:

    cycle_epoch  host  check  previous_state  new_state  source  message

Epoch values are UTC epoch seconds. The supplied `--received-at` and `--now` options make tests deterministic. Repeating a cycle without a state change does not append another event.
