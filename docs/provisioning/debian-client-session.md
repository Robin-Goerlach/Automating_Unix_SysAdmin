# Debian client development handoff

Deutsch: [Deutsche Fassung](debian-client-session.de.md)

2026-11-25 — independent GitHub development on feature/debian-client-checklist. Do not modify main or the other active development session. Baseline: e5e947cf1bb536eee53089a20891f69b76648f93. User requested autonomous continuation in chat; no second Codex session. Local ../logs/LAST-SESSION.md is inaccessible from this environment. This sanitized repository document is the separate handoff; never include private site configuration or secrets.

Completed: static read-only baseline checker and negative fixture tests, integrated test entry and archive member. Local fixture test as nobody passed (three initial file hashes unchanged). GitHub clone from the local container failed DNS resolution; no full make test or native Debian evidence. No live apply. The previous stage's complete CI status remains unknown. Next: centralize policy validation, implement fixture-backed atomic managed file installation preserving unrelated hosts entries, then dependency gates, rollback and task-specific verification. Only after acceptance enable an explicit native lab apply path. No automatic monitoring approval.

## M7-D.1a — fixture application checkpoint

Starting commit: 8e0d7fa8b48a546e15a99d6a8e659d79a91295b6. Shared policy validation, fixture-only apply-baseline.sh, read-only verifier tightened, test-apply.sh and packaging/test integration added. Executed the four new/refactored files locally as nobody; test-apply.sh passed with unchanged hashes after an injected final verification failure. Local GitHub DNS resolution failed again; full make test was not run. No native apply. Next: add explicit transaction evidence and operator-reviewed recovery, enforce task dependencies and central inventory selection, integrate the fixture path with the numbered tasks, then plan native Debian acceptance. Do not merge main or interact with the parallel Codex session. Retained backups grow per fixture apply; bounded cleanup and crash recovery are future work.

## M7-D.1b — journal and recovery checkpoint

Base: 14575c917e32d78250305d0e92bb9688d424c991. Added retained before/desired manifests, state transitions, directory flock, explicit recovery, and two local tests. Both tests passed as nobody in a Linux container, including real process SIGKILL after replacement, blocked reapply, restored original manifest, successful retry and unchanged repeat. Local GitHub DNS resolution failed; full repository tests and native Debian acceptance not run. Exact local hashes of the five changed/new scripts checked before publication. Next M7-D.1c: explicit task prerequisites and central inventory selection, followed by dispatcher integration. Keep main and parallel Codex work untouched. Power-loss durability, old backup migration, automatic pruning and reboot resume remain open.

## M7-D.1c — read-only planning checkpoint

Base: 1f5f5bf27ff49d4771e80875c616c761ca729914. Added plan-client.pl, dependencies.tsv (23 initial edges), test-plan.sh and test entry. Reused R2 validator without changes. Local syntax and unprivileged test-plan.sh passed with the exact published inventory validator and complete 116-row catalog (Git blob hashes matched), and synthetic no-execution task fixtures with matching names. New source blobs checked before branch update. Direct clone still fails DNS; complete repository tests, native Debian and CI not verified. No dispatcher enforcement or packaging integration yet; no live changes. Next M7-D.1d: bind validated inventory and plan to dispatcher, establish evidence contract and guard fixture execution; complete dependency coverage before native apply. Keep main and parallel Codex work untouched.

## M7-D.1d.1 — candidate dispatcher integration

Base 1cb65f33e6c09deeba3c1e4761f1ecafb7d06ad8. Integrated inventory-aware dryrun/stage and prerequisite enforcement, candidate hashes and allowlisted archive portability. Exact new dispatch-planned.sh tested as nobody against synthetic four-task planner and scripts; published blob checked. Real-catalog/packaging test added but not run; direct GitHub clone DNS unavailable, CI/native unverified. Next M7-D.1d.2: bounded transaction-backed fixture baseline apply and verified evidence, then native gate. Legacy no-inventory dryrun remains; no live apply. Main untouched.

## M7-D.1d.2 — fixture transaction dispatcher checkpoint

Base 80f506e05ca7ed4ca47bb29167780e8eaab1c57c. Added explicit inventory-bound baseline group transaction and private point-in-time evidence. Local unprivileged test-fixture-dispatch.sh passed with exact current entrypoint/planner/R2/catalog/dependency/transaction/policy/verifier files and synthetic task names, including repeat, conflict, changed dependency and pending journal. Root rejected. Exact new script blobs checked. Package and test entry updated, full archive and repository suite not run; no native writes. Next: M7-D.1e preparation, native acceptance contract (resolver ownership, runtime hostname/DNS, rollback, Debian version), complete offline integration where feasible; no live apply before disposable native gate. Main untouched. Known gaps: evidence lock gap, unsigned point-in-time report, no general verified edge enforcement or retention policy, DNS runtime open.
