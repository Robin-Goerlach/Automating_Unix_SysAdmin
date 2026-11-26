# M7-D.7h — first isolated Debian KVM lab: decision packet

Deutsch: [Deutsche Fassung](debian-client-lab-decision.de.md)

Status: **PREPARATION ONLY — NATIVE EXECUTION NOT AUTHORIZED.** Consolidates, does not supersede, the [native acceptance contract](debian-client-native-acceptance.md), [lab runbook](debian-client-lab-runbook.md) and [integration plan](debian-client-integration-plan.md). No VM has been created or accessed by this work.

## 1. Pinned development state and CI

Main feeb68f8fcd26835ae570b38c5f4ce68b4b8a54d, CI #67 SUCCESS; original feature 01de137d88eddd71a7958b13fbc27035adfff78c unchanged. Integration documentation commit 3e77579a690dfe6b5eb2a83cb686d5abd38c7187, CI #69 FAILURE. Job 139827130484: source connected workflow PASS; archive workflow stopped at fixture-apply exit 2, invalid fixture or root execution. Source inspection: Python TemporaryDirectory may generate underscores, whereas legacy lib/transaction.sh fixture_check permits only alphanumeric suffixes. The log does not record the actual suffix, so this is the supported likely cause, not direct observation of the failed pathname. Test-only fix 278656ece5aa68300f85c21496fa729f13e7f21f uses /usr/bin/mktemp -d /tmp/sasd-debian-lab.XXXXXXXX, asserts alphanumeric path and ownership, retains cleanup. No guard weakened, no runtime change. [CI #70](https://github.com/Robin-Goerlach/Automating_Unix_SysAdmin/actions/runs/45804067913) pending during preparation. [CI #68](https://github.com/Robin-Goerlach/Automating_Unix_SysAdmin/actions/runs/45793947395) previously passed both source and extracted connected workflow (116 tasks, 39 staged, 171 archive files, three static baseline files, ten static groups, 57 waiting edges, child interruption/recovery). Prior PASS not proof for new commit; M3 native and tcsh checks skipped. No native accepted task.

PR #4 remains draft/dirty; integration I0 assessed pinned earlier heads, I1–I5 open. Refresh all pins and three-tree comparison before authorized reconciliation, including the test fix and this documentation. No merge/rebase, no candidate tree, no local combined suite. Keep old releases, references and inputs for unresolved journals.

## 2. Recommended decisions and boundaries

| Decision | Recommendation | Authorization boundary |
|---|---|---|
| A — integration | Approve a separate reconciliation branch only; preserve both histories and original heads; validate I2–I5 | Explicit approval; no main merge now |
| B — first lab | Debian 13 amd64 minimal, KVM/libvirt, one local ext4 filesystem for /etc and /var, workstation role with baseline profile | Operator chooses disposable VM and confirms console/snapshot; no guest writes by this preparation |
| C — read-only collection | After reviewed test fix and independently trusted release, collect G1/G2 on approved isolated VM as ordinary user; no DNS by default | Separate operator confirmation; no sudo, native initialization or apply |
| D — native baseline | Only after combined I gates, lifecycle enforcement, G0–G2 and reviewed G3 readiness | Separate explicit decision with exact release, VM identity, approved inputs and recovery plan |
| E — later integration/release | Actual native acceptance G4–G6 and distinct M6/M7/product acceptance | No V1.1 or production release now |

Suggested VM sizing (planning default, not a measured minimum): 2 vCPU, 4 GiB RAM, 24 GiB virtual disk. Debian 12, XFS, alternate architectures, managed resolver and separate /etc or /var mounts are separate profiles, not fallback bypasses. Use an isolated host-only network with no route to production, no production DNS, mounts, secrets or credentials. Prepare packages through normal OS installation: shell, Perl, Python3, coreutils, util-linux/flock, iproute2, systemd tools, optionally dig for later G5. No package install by the provisioning scripts. The operator must prove the network design, actual IP, DNS policy, console access without DNS and snapshot restoration on a disposable clone; virtualization detection alone is insufficient. Do not disable a resolver manager to fit the test.

## 3. Gate sequence and evidence checklist

| Gate | Required evidence before approval | Status |
|---|---|---|
| G0 | Reviewed exact commit; ordinary-user make test, source/archive workflow, package allowlist and independent trusted archive/runtime digest; combined I2–I5 acceptance before native mutation; relevant skips resolved | OPEN |
| G1 | VM identity and isolation, Debian/kernel/tools, ext4 layout, clean snapshot ID and tested restore, console without network | OPEN |
| G2 | R2 host selection, explicit enabled lifecycle and approval-context binding before native mutation; release and identity review, actual existing IPv4, resolver ownership proven independently, preflight/capabilities/rehearsal and reviewed differences | OPEN |
| G3 | Separately authorized fixed-scope writer, approved root-owned release/inputs, identity/metadata/storage checks, exclusive administration and rollback/restore procedure | OPEN |
| G4 | Static match and actual runtime hostname/FQDN/address, console and management access intact | OPEN |
| G5 | Direct DNS A match to each approved resolver, independent NSS match, negative and unreachable lab cases, no false success | OPEN |
| G6 | Repeat/no unintended changes, interrupted apply and rollback, reboot, tested snapshot restore and recorded journal/durability outcomes | OPEN |

Early unprivileged G1/G2 observations may be collected on a reviewed independent integration snapshot with separate approval; they must be repeated against the final candidate where release/context changes. They do not close G0/G2 or authorize G3. Before any native write, all I0–I5 and G0–G2 conditions and explicit G3 decision must be reviewed. A combined offline PASS alone cannot close native gates.

## 4. R2 lifecycle blocker

The current Debian planner consumes the canonical six-field R2 list, but not main's authoritative host-state projection. The native CLI binds hosts.tsv, roles.tsv and site.conf but not lifecycle. Main supports enabled/disabled/removed and a missing default state can imply enabled. For native provisioning choose an explicit authoritative state path and require an explicit enabled record for the selected host; unknown, disabled, removed, missing, invalid or stale state must block. Reuse main's read_host_state parser, do not invent a second inventory. Proposed future design: freeze validated lifecycle input in the reference/plan/release context and recheck it under the same native mutation lock before first write; changed lifecycle must invalidate new apply. Define separately whether a disabled/removed host permits restricted rollback of an already-open transaction under its original context (operator review, no new apply); never silently promote or abandon recovery. Tests: legacy/marked inventory, malformed/unsupported/duplicate marker, missing explicit state, unknown or duplicate state, disabled/removed, stale approval and changes between review/apply. No implementation of this gate in this documentation commit. Manual checks alone do not substitute for the native guard; block G3 until implemented and combined tests pass.

## 5. First approved read-only session

The runbook provides actual commands. On trusted dev checkout, verify full commit, clean status and ordinary-user make test, make release-test and Debian package. Record archive SHA-256 independently via a trusted separate channel and verify before extraction. No root execution from an untrusted archive. On approved VM create a new private 0700 work directory, use umask 077 and extract reviewed archive as ordinary user. Use actual lab values from R2: lowercase FQDN, canonical existing IPv4, approved DNS and search domain; workstation role/baseline profile, six fields with empty groups allowed. Do not use .invalid or documentation addresses as real targets. No production data in Git.

    ./debian-client/collect-native.sh --live --hostname="$HOST" \
        --inventory=hosts.tsv --roles=roles.tsv --site=site.conf

Expected completed collection: exit 3, COLLECTED_NOT_AUTHORIZED. Exit 2 or missing final status is incomplete/error, not successful observation. G2 BLOCKED is expected with incomplete unprivileged capability visibility, absent native store or unsuitable resolver; even REVIEW_REQUIRED is not acceptance. G5 NOT_RUN unless explicitly paired approved probe arguments; initial collection omits those. The collector copies inputs and rehearses on private fixture copies, not actual configuration files. It writes private reports under /tmp; archive locally before reboot using reviewed operator procedure; retain mode 0700/0600, no raw data in Git. Inspect status, scope, created-utc, commands.tsv, gates.tsv, input.sha256, plan.tsv, preflight.tsv, capabilities.tsv, observations.tsv, rehearsal/status and rehearsal/changes.tsv if present. The legacy G3 reason no-native-writer-or-authorization means OPEN/no authorization; a writer now exists. Never treat native-preflight exit 0 as a gate PASS. Stop after collection and review.

## 6. Later privileged phase — not authorized here

Only 0010, 0030, 0040 are in the experimental static native writer: /etc/resolv.conf, /etc/hostname, /etc/hosts. 0020 runtime DNS is separate; 0370 final resolver and all other group fixtures are not native. No runtime hostname change, IP reconfiguration, firewall, package/service activation, mounts, enrollment or monitoring send. Resolver file change can immediately affect DNS. Approved root-owned release fixed at /opt/sasd/debian-client; storage /var/lib/sasd/provisioning with independently assigned installation-id, transactions and approved directories (0700). Approved site.conf, hosts.tsv, roles.tsv and authorization.json; lifecycle binding must be added before approval. No automatic initialization. Actual root UID/GID, KVM/QEMU, supported filesystems/flags, no unsupported xattrs/ACLs, regular single-link root-owned targets, safe metadata, current IPv4 and proven static resolver required. Review/apply require NetworkManager/systemd-resolved/systemd-networkd observed inactive; independent proof of no other owner still required. No alternative root. Independent identity/fingerprint/release digests are mandatory; flags are operator attestations, not proof. Do not use fixture references or checkpoints for native approval.

After separate approval, native review must match independent originals/desired bytes and produce SASD-NATIVE-REFERENCE-1 STATIC_LAB_ONLY; only independently reviewed exact JSON becomes authorization. Apply and recovery command preparation is deliberately deferred to actual G3 review; no copy-paste root mutation command here. A successful COMMITTED_STATIC is not G4/G5/G6. Keep console, snapshot and separate evidence accessible. Direct DNS verifier requires approved server/name/expected A and explicit live mode; NSS can answer via non-DNS sources, so test independently. Record actual runtime hostname after reboot, not just stored file.

## 7. Failure and recovery decision table

| Situation | Action |
|---|---|
| Drift/unknown or unsafe metadata before apply | Stop; review, never weaken guards |
| APPLYING or ROLLING_BACK | No new apply; retain exact old release/input/reference; inspect sole open journal; explicit reviewed recovery only if each current target equals original or desired |
| SYNC_FAILED, unexpected store entry, missing approval, identity/release mismatch, unrelated edit | Stop; do not delete quarantine or journals; review storage/restore snapshot under console |
| COMMITTED_STATIC followed by DNS/runtime failure | No closed-journal rollback exists; use approved console/snapshot fallback |
| Fixture checkpoint mismatch | Review only, not native recovery evidence |
| After recovery/reboot | Recollect actual evidence; do not reuse stale approval or claim durability from terminal journal alone |

G6 must use disposable VM trials including controlled interruption during native apply/rollback and actual reboot, not physical power-cut claims. Preserve originals and pre/post hashes/modes, journal states and exact outcome. Snapshot restoration rolls back guest disk history; retain relevant evidence separately and securely before restore. No automatic retry after error.

## 8. Operator evidence record (private, not repository data)

For each gate record UTC time, operator/VM identifier, exact reviewed commit and CI run, archive and runtime digests, OS/kernel/tool versions, isolation/console/snapshot test outcome, selected host lifecycle state and state digest, input/plan hashes, command/exit/status, raw evidence path and digest, decision PASS/FAIL/BLOCKED/NOT_RUN/SKIPPED and reason. Never fill a PASS from a synthetic observation. Record baseline original/desired/current metadata hashes, identity match (not raw IDs), DNS and NSS separately, journal and restore result. Keep report originals, private inputs, fingerprints and authorization outside Git; share only redacted status rows/exit codes and findings. Separate independent approvals from same-source hashes; no signature/replay protection claimed.

## 9. Next explicit decision

Recommendation: approve I1 only (separate reconciliation candidate, no main merge, no native mutation) after test-fix CI success; implement/test lifecycle guard in that candidate, execute combined I2–I5 and review. In parallel planning only, select the proposed isolated Debian 13 KVM baseline. Ask for actual VM details when the approved read-only session is reached, not now. Operator retains final authority for main integration, actual VM preparation/access and all native operations. No local external session logs available; repository handoff records this limit. No native operation, merge, rebase, release or gate closure performed.

## I3/I4 — combined acceptance and write-boundary hardening

CI #72 (45804862788, job 139857308423, merge 8bd0bb2) and CI #73 (45805072689, job 139858038278, lifecycle bc858a2) SUCCESS. Full job logs retrieved; integrated site lab PASS, separate restricted SSH integration PASS, Debian source and extracted connected workflow PASS twice, 171 exact runtime files, 116 tasks, 39 staged, 57 waiting edges, ten groups, three static baseline files, child interruption/rollback and checkpoint mismatch/match; #73 explicit R2 lifecycle checks pass. Both clean source extractions PASS and archive byte comparison successful. M3 MRTG/RRDtool native, tcsh syntax, native product daemons/network boot/production deployment remain skipped. CI warning checkout@v4 Node20 forced onto Node24; maintenance review separate. Results apply to the exact tested commits, not the following hardening.

Native transaction primitives now optionally call a context guard before initial journal, each target step and terminal commit/rollback. Native CLI always supplies it: exact private (0600, single-link, owner/group, no xattrs) authorization JSON re-read before/after approved_plan; four input hashes, plan and explicit enabled lifecycle rechecked against independent pinned digest under existing cooperative lock. Apply/recovery compare complete expected intermediate target snapshots, not only current target. Guard rejection before journal means no new transaction; after journal leaves APPLYING/ROLLING_BACK, not false terminal success. Existing fixtures keep default guard=None; no new native task, no change to fixture authorization. New synthetic tests exercise actual partial apply after lifecycle disabled, denied recovery, same-context test-only rollback, authorization revocation mid-rollback and private authorization mode. Tests do not permit re-enabling or restoring stale state to bypass real recovery.

Conservative recovery rule retained for first VM: a revoked/changed/missing authoritative state or approval blocks new apply AND CLI recovery; preserve journal and use separately approved console/snapshot recovery, keeping central host disabled/removed. No automatic exception or stale snapshot replay. A future independent rollback-only authorization design could be considered after native lab evidence, with identity, original release, journal digest and current authoritative state, never forward apply. Local guard checks are sequential/cooperative, not atomic against independent privileged writers or a central change not yet imported; operator must keep current state and exclusive administration, G3 remains open.

Collector G3 reason now experimental-writer-not-authorized, same OPEN status. make release-test now fails fast, verifies both SHA256SUMS, compares archives AND manifests, checks manifest against exact HEAD tree, prints digests and reproducible-distribution=PASS. This strengthens I4 but does not authenticate a delivered archive independently. Source/archive runtime count unchanged (171). New candidate CI pending; I3/I4 previously proven for bc858a2, must repeat on final commit. I5 operator approval and independent trust remain open, all G0–G6 open. No root/native operation or main merge.


## I5 — current decision status

See [I5 decision packet](debian-client-i5-decision.md). I1 approved and separate two-parent candidate created. CI #72/#73 passed; #74 failed before Debian execution, literal replacement fix a1ee2f1 published, #75 pending at initial review. Final exact-commit CI and separate main approval required. Lifecycle snapshot binding implemented but native freshness/ownership and G0–G6 not accepted. No native operation or main update.
