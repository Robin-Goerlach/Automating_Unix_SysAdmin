# M7-D.7g — branch integration and acceptance plan

Deutsch: [Deutsche Fassung](debian-client-integration-plan.de.md)

Status: **PREPARED — NOT MERGED — COMBINED ACCEPTANCE OPEN.** This is a pinned, read-only assessment and a proposed reconciliation, not a resolved merge tree, authorization, or V1.1 release decision. Keep the [native acceptance contract](debian-client-native-acceptance.md) and [client design](debian-client.md) in force.

## 1. Verified inputs and evidence

| Role | Exact Git commit | Result |
|---|---|---|
| Common ancestor | a245e2d404d8d00068e3fa8ed99964e4141ecf89 | merge base returned by compare API |
| main | feeb68f8fcd26835ae570b38c5f4ce68b4b8a54d | [CI #67](https://github.com/Robin-Goerlach/Automating_Unix_SysAdmin/actions/runs/45793524991) SUCCESS |
| integration/debian-client-checklist before this documentation | f9ff5530614eaa58153b83e9b8e8aead07987a66 | [CI #68](https://github.com/Robin-Goerlach/Automating_Unix_SysAdmin/actions/runs/45793947395) SUCCESS |
| original feature branch | 01de137d88eddd71a7958b13fbc27035adfff78c | unchanged, retain |

Both job logs were retrieved. Main job 139818242136 reports SASD integrated offline site laboratory PASS, M3 native MRTG/RRDtool skipped and native daemons/network boot/production deployment skipped. Integration job 139819680319 reports SASD-OFFLINE-WORKFLOW-TEST-1 PASS twice (source and extracted archive), 116 tasks, 39 staged, three baseline static files, ten group observations, 57 waiting dependency edges, partial child-write exit, ROLLED_BACK, old checkpoint EVIDENCE_CHANGED and new checkpoint CHECKPOINT_MATCH_REVIEW_ONLY. Archive integration reports 171 exact files; M3 native and tcsh syntax checks skipped. Native verification NOT_VERIFIED, execution NOT_AUTHORIZED. Do not promote either branch's independent success to combined success.

GitHub comparison reports integration 52 commits ahead and seven behind. Recursive tree results were complete. Compared blob paths, hashes and modes against the ancestor: main changed 55 paths (36 modified, 19 added), integration changed 231 paths; no deletions on either side. Three paths changed differently on both sides; no identical overlapping changes. Union 283 changed paths (52 main-only, 228 integration-only, three overlaps). PR #4 open/draft, mergeable false, dirty. The PR's reported base SHA was the old common ancestor; use actual branch heads and compare API, not the stale PR base field. [PR #4](https://github.com/Robin-Goerlach/Automating_Unix_SysAdmin/pull/4).

## 2. Preserve both bodies of work

Main's seven commits, in order:

- 4a009a0: consolidate site validation and CFEngine 1 adapter.
- 0d48c3d: shared host state parser and CFEngine 2 adapter.
- 2a35193: version site inventory and Big Brother candidate.
- 76ea07b: Big Sister integration and inventory migration hardening.
- 08f5604: checkpoint status.
- a5dd317: integrated offline monitoring laboratory.
- feeb68f: controlled configuration deployment.

Preserve all main-only changes, including AGENTS.md/AGENTS.de.md readability guidance, shared Perl library, inventory migration, host lifecycle, independent product adapters, documentation, deployment, tests and integrated lab. Preserve integration-only changes, including independent CI push trigger, full Debian subtree, native experimental baseline guards, source/archive tests, bilingual design and session history. Neither branch owns the other's domain. Do not resurrect old validator/module copies or overwrite main with the integration tree. Do not merge the original feature branch separately.

## 3. Overlap review and exact reconciliation proposal

Compared the ancestor and both full versions of each of the three paths. Line numbers below refer to the common ancestor (insertion before a line, or after the final line). This is a textual edit analysis, not an executed Git merge or proven conflict-marker list.

| Path | main edits | integration edits | Proposed resolution |
|---|---|---|---|
| Makefile | line 2, insert before 8/9/19/21, replace 24–25 | insert before 19 | Take main complete file, insert Debian test once after integrated-site-lab example and before deployment-test target |
| docs/ROADMAP.md | insert before 17; replace 52 and 112 | append M7-D before line 174 (end) | Preserve main checkpoint A–F and product progress; append reconciled M7-D section below |
| docs/ROADMAP.de.md | insert before 17; replace 25 and 91; append before 142 (end) | append M7-D before 142 (end) | Preserve main final deployment paragraph, then append parallel M7-D section |

The Makefile insertion point and German roadmap end are actual overlapping edit locations; English roadmap edits are disjoint in the line comparison. Git reports dirty; no merge was attempted and exact conflict hunks remain untested. No blanket ours/theirs or strategy option.

### Makefile proposed test contract

Start from exact main Makefile. Keep .PHONY targets test, syntax, release-test, site-test, integrated-site-lab, deployment-test. Keep both existing syntax loops (all new product and deployment commands). Keep all main test recipe lines, in order. Add exactly one tab-indented line immediately after the recipe line "sh examples/sasd-integrated-site-lab.sh" inside test (not inside the dedicated lab target):

    sh install/debian-client/test.sh

This preserves main's 21 recipe commands (including docs-pairs) plus one Debian suite, following syntax prerequisite. Debian suite invokes its own shell syntax and 46 component/assembly test scripts, including source and archive workflows. Do not duplicate the Debian test or replace main test/syntax with the older version. Keep release-test unchanged; additionally run the Debian archive check and extracted-source suite because the repository-wide release --test only exercises a subset. Preserve integration workflow .github/workflows/test.yml (main and integration push branches, pull_request, contents: read, make test); main's copy has no integration push trigger. Any separate reconciliation branch CI must have a reviewed trigger or explicit equivalent local test; do not assume a conflicted PR will run.

### Proposed shared M7-D roadmap block (English)

- Modern Debian checklist: 116 original markers, 89 local candidates, 11 central, 16 manual; 57 dependency edges. 34 bounded apply IDs (three experimental baseline, 23 config fixtures, four state models, four policy records), 16 verify-only, 39 candidate-only. Zero native accepted.
- R2 remains the only inventory authority. Reuse the versioned shared inventory, lifecycle and product model from main; preserve stricter Debian FQDN/canonical IPv4 checks. Lifecycle-aware provisioning and central registration/removal are not yet implemented.
- Offline review, transaction, recovery, evidence, orchestration and checkpoint workflow verified on the integration branch. Static observations do not satisfy native prerequisites. Combined branch acceptance remains open.
- Complete remaining safe backends, owner/order rules for shared files, actual runtime verification, explicit enrollment approval and disposable VM G0–G6; keep all historical product and V1.1 gates unchanged.
- See [client design](debian-client.md), [native contract](debian-client-native-acceptance.md) and this integration plan.

Main's B/F checkpoint and earlier checklist text must be reconciled, not blindly retained as current fact: bounded controlled deployment is now implemented offline (not native deployment or complete orchestration); product generators and migration are implemented while further deployment orchestration remains open. Apply the same distinctions in both languages; E should mention modern Debian offline progress without marking native network boot/postinstallation accepted. Preserve A/C/D and unrelated planned items. No rewrite of canonical roadmaps in this preparation commit.

## 4. Semantic interface risks (no textual conflict required)

| Contract | Observation from source | Mandatory combined acceptance |
|---|---|---|
| R2 validator | main now delegates sasd-site-inventory to SASD::Monitor read_inventory; six-field list and host query retained; supports legacy and SASD-SITE-INVENTORY-1 marker | Exact plan output for same valid legacy and marked inventory; unsupported/misplaced/duplicate marker rejected; duplicate host/address, unknown role, conflicting profile rejected |
| Debian-specific restrictions | plan-client.pl independently rejects case-insensitive duplicate hosts, noncanonical IPv4 and non-Debian selected record | Preserve those guards even if main validator is more permissive |
| Host lifecycle | main read_host_state enabled/disabled/removed; Debian planner currently consumes validator --list without a lifecycle input | Explicitly decide authoritative lifecycle path and fail-closed policy before any native dispatch. Add disabled/removed, unknown state, missing explicit state and stale approval tests. Do not silently assume enabled from a six-field record. No second inventory, no production writes |
| Archive dependencies | package.sh copies current canonical bin/sasd-site-inventory and lib/SASD/Monitor.pm; main validator uses FindBin ../lib; archive placement lib/sasd-site-inventory and lib/SASD/Monitor.pm is compatible by inspection | Byte/mode compare exact combined versions, exercise without surrounding checkout, missing library refusal, unchanged canonical plan hash for same input; do not vendor old code |
| Release identity | lab-install.release_digest includes both canonical dependencies; replacing them changes release identity even without Debian file changes | Rebuild all fixture references, manifests/evidence and checkpoints in clean roots with new release; retain old archive/input/reference for unresolved journals. Never patch/re-sign old reference to pass |
| Monitoring | main adds external status measurement/freshness validation and retains four-field status compatibility; Debian uses read_checks/applicable_checks/validate_status | Existing M1/M2, BB/BS adapters and Debian preview tests pass; check role, invalid/duplicate/stale/conflicting observations; NEVER import, sign, send or approve synthetic preview |
| Central deploy vs client provisioning | main sasd-config-deploy stages host-services/BB/BS/CFEngine configs into disposable prefix using own manifest/plan/backup; Debian fixture journals use different format and roots | Separate namespaces, no automatic chain or journal interchange; verify drift rejection, rollback and no unintended writes on each. Future composition needs explicit ownership and ordering |
| Shared targets | baseline and network group both model hosts/resolv.conf | No common native writer yet. Agree owner/order, resolver manager and handoff evidence before native application |
| Historical and modern paths | main AGENTS retains 1999/later profiles; Python/Linux is modern Debian only | Historical entrypoints remain POSIX/Perl, do not introduce mandatory Python/systemd in historical runtime |

No site policy, lifecycle data, actual package sources, DNS registration, monitoring checks or enrollment approvals are changed by this document. Default hardware check catalog still requires explicit review before real use.

## 5. Future authorized reconciliation procedure

The following commands are READ-ONLY verification examples, not merge instructions to run now. Use a trusted checkout with all objects, no production credentials, ordinary user and clean worktree. Revalidate pins; if either branch advances, refresh the analysis before proceeding.

    BASE=a245e2d404d8d00068e3fa8ed99964e4141ecf89
    MAIN=feeb68f8fcd26835ae570b38c5f4ce68b4b8a54d
    INTEGRATION=f9ff5530614eaa58153b83e9b8e8aead07987a66
    git merge-base "$MAIN" "$INTEGRATION"
    git diff --name-status "$BASE" "$MAIN"
    git diff --name-status "$BASE" "$INTEGRATION"
    git diff "$BASE" "$MAIN" -- Makefile docs/ROADMAP.md docs/ROADMAP.de.md
    git diff "$BASE" "$INTEGRATION" -- Makefile docs/ROADMAP.md docs/ROADMAP.de.md

After explicit operator approval only: create an isolated reconciliation branch/worktree from pinned current main, preserve history from both parents, resolve only reviewed overlaps and required semantic adaptations, document every exception. Do not push main or original feature. No force push, rebase or history rewrite; no squash that discards required history. If remote heads change, stop and re-evaluate. For a future candidate CANDIDATE, check both ancestor relations with git merge-base --is-ancestor, compare complete trees/path modes and require each single-side changed path to match that side exactly except separately reviewed changes. Verify all 283 changed paths from this baseline plus subsequent documentation commits; no missing paths, unwanted removals, secret copies, mode drift, or extra unreviewed changes. Keep both original heads reachable. Check diff --check and inspect the full combined change. No candidate has been created here.

## 6. Acceptance gates and handoff

| Gate | Required evidence | Current status |
|---|---|---|
| I0 pinned comparison | Full heads, ancestor, path/hash/mode union, separate CI and logs | PASS for pinned inputs |
| I1 operator approval | Explicit approval for reconciliation only, fresh pins and preserved branches | OPEN |
| I2 reviewed candidate | Both histories retained, tree union/exception review, bilingual roadmap parity, exact shared contracts | OPEN |
| I3 combined offline | Full ordinary-user make test on exact candidate; main lab and Debian source/archive workflow PASS, all skips explicitly recorded | OPEN |
| I4 distribution | make release-test, deterministic source archives, Debian package allowlist and clean extraction, independent expected SHA-256 recorded | OPEN |
| I5 release review | Combined CI green on exact candidate, no missing regressions, documented limits, operator decides PR/main integration | OPEN |
| Native G0–G6 | Existing native contract, disposable Debian VM, console/snapshot, read-only preflight, separately authorized baseline, DNS/NSS, reboot/recovery | ALL OPEN |

After I1/I2, run ordinary-user make test, make site-test, make deployment-test, make integrated-site-lab, sh install/debian-client/test.sh, sh install/debian-client/test-offline-workflow.sh and make release-test. Record commit, OS, versions, UID, commands, exit codes and log hashes; distinguish redundant focused runs for diagnosis. In extracted source archive (no .git), run applicable component tests directly, not the Git-dependent docs-pairs script; check Debian archive separately through its actual test-archive.sh. Expect 116 rows, 39 staged, 171 Debian runtime files unless a reviewed change updates contract, all ten groups, three baseline files, 57 waiting edges, actual interrupted child/recovery and checkpoint mismatch/match. Require the new R2/lifecycle contract regressions described above before native use. Missing tcsh, native MRTG/RRDtool or product daemon tests remain SKIPPED/NOT TESTED, not PASS; relevant missing prerequisites block native acceptance, not claimed by offline CI. Confirm no native changes, no authenticated fixture status ingestion and no automatic native dependency promotion.

I0 is preparation only. No merge/rebase, candidate build, local combined suite, native test or actual branch conflict resolution executed. Direct local Git access previously unavailable due DNS; external operator logs not accessible through this interface. Preserve old release references for recovery. Next D.7h: prepare read-only native lab checklist/evidence and decision packet; integration I1–I5 and all G gates remain subject to explicit approval. V1.0 remains unchanged; no V1.1 release.
