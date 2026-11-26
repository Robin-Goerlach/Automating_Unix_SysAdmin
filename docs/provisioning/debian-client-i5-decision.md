# I5 — decision on integration into main and native laboratory

Deutsch: [Deutsche Fassung](debian-client-i5-decision.de.md)

**Status: REVIEW PREPARED — NOT APPROVED.** Do not merge, tag, publish a release or execute privileged provisioning based on this document. I1 authorized only the separate reconciliation branch.

## 1. Exact inputs and evidence

Common ancestor a245e2d404d8d00068e3fa8ed99964e4141ecf89; main feeb68f8fcd26835ae570b38c5f4ce68b4b8a54d; independent client line f50abc84bc71a5c10ef988b12e4f87cf6af01b62; original feature 01de137d88eddd71a7958b13fbc27035adfff78c. Merge 8bd0bb2224e40ac78eb83429c990303f5693fa46 has both parents; compare reports zero commits behind each for reviewed correction a1ee2f197f8b23e47b290e95f9ee3967412e69e8. No history rewrite. Refresh pins before any decision.

| CI | Exact scope | Result |
|---|---|---|
| #72 / 45804862788 | Merge 8bd0bb2 | SUCCESS |
| #73 / 45805072689 | Lifecycle bc858a2 | SUCCESS |
| #74 / 45805684085 | Write-boundary hardening a358852 | FAILURE |
| #75 / 45809695510 | Literal substitution correction a1ee2f1 | IN_PROGRESS  at review |

Full #74 job 139860184193 (261 lines) reviewed: central smoke, R2, CFEngine, BB/BS, monitoring, restricted SSH, M4–M7 offline, controlled deployment and site lab passed. Debian shell syntax stopped at test-collect-native.sh:72, unterminated quote. Lifecycle and distribution steps not executed. Cause: JavaScript replacement string interpreted dollar-quote syntax in grep replacement, duplicating trailing script; same mechanism collapsed doubled Make dollar escapes. Correction reconstructs collector test from known-good bc858a2 with one literal replacement and restores Make recipe double dollars. No intended guard weakened. CI #75 must prove both fixes and actual extended lifecycle tests. No independent local suite. No new test success inferred from earlier runs.

## 2. Completeness audit

Complete recursive Git trees at the pinned ancestor, both parents and correction: 433 union paths, 436 candidate paths, zero missing, zero mode changes. Three additional paths: bilingual reconciliation reports and test-r2-lifecycle.sh. Seventeen inherited paths differ from the selected side: Makefile, two roadmaps, CI workflow, six bilingual lab/acceptance/session documents, collect-native.sh, native-install.py, plan-client.pl, test-archive.sh, test-collect-native.sh, test-native-install.sh, test.sh. These are the documented reconciliation, guard, test and handoff edits, not lost paths. This packet adds a bilingual decision pair and updates roadmaps/handoffs only. Verify the final published tree again. No blanket ours/theirs. Original branches unchanged.

## 3. Semantic risk and acceptance boundaries

| Area | Evidence/limit | Disposition |
|---|---|---|
| R2 versioned inventory | canonical parser, stricter Debian checks; #73 legacy/marked plan and lifecycle tests pass | retain; recheck final CI |
| Lifecycle | local explicit enabled snapshot, independent digest; no live central revocation | native blocker until operator freshness and exclusive administration demonstrated |
| Write guard | checks at transaction boundaries; #74 never reached these tests | final CI required; no atomicity against privileged external writers |
| Recovery | revoked/changed context blocks apply and CLI rollback; open journal retained | keep console/snapshot fallback; no stale snapshot replay; future rollback-only approval separate |
| Shared hosts/resolv.conf | baseline and network group use independent fixture roots | only three baseline targets native; no combined native writer or final resolver ownership assumption |
| Shared library/packaging | canonical validator and Monitor.pm included, 171 exact runtime files verified #73 | new release invalidates old references; final archive regression required |
| Monitoring/enrollment | site lab and restricted SSH passed; synthetic preview never native/authenticated evidence | no automatic registration, signing/import/sending synthetic preview |
| Deployment | central deployment and client fixture journals distinct | no implicit chaining or journal exchange |
| Distribution | previous clean extraction and deterministic archives; #74 enhanced test skipped | require two clean extractions, both checksums, manifests/tree and archive equality, reproducible-distribution=PASS; independently trusted delivery hash still separate |
| Historical scope | M3 native MRTG/RRDtool and tcsh skipped; real product daemons, netboot and production deployment not run | remain explicitly unaccepted, not claims of compatibility |

Static acceptance only: 116 tasks, 89 local, 34 bounded apply IDs (including three experimental native baseline), 16 verify-only and 39 candidate-only; 11 central and 16 manual. 57 prerequisite edges, 39 staged, ten fixture groups, three static baseline files. Zero native accepted. Test coverage is scenario coverage, not line coverage or proof of all profiles. No measured physical power-loss evidence.

## 4. I5 decision checklist

Before approval: exact final candidate CI green, full logs inspected (both lifecycle test markers, both connected-workflow PASS markers, exact Debian archive count, main lab, both clean-extraction and distribution PASS, explicit skips); reviewed diff/tree and both ancestors; current main unchanged or repeat analysis; review workflow permissions and Node20 checkout warning (maintenance separate, not an offline failure); no secrets in changed docs; clean diff/whitespace and bilingual links. Record exact commit, run/job IDs and archive digests. A documentation-only follow-up still needs CI for its exact commit. A source distribution checksum is not independent authenticity.

Decision A (separate explicit approval): integrate exact reviewed candidate into unchanged main, preserving both histories, without force/rebase/squash. Fast-forward only if verified ancestry and unchanged pins; otherwise stop, no automatic merge. Retain old branches; PR #4 remains old/conflicted, do not merge it or silently retarget. After update, verify exact main head and main CI; if failure, review separately, no automatic destructive rollback. No V1.1 release, no native authorization. Until final CI succeeds recommendation is HOLD.

Decision B (separate approval): prepare disposable Debian 13 amd64 minimal KVM/libvirt VM, 2 vCPU, 4 GiB, 24 GiB ext4, host-only isolated network, console and tested snapshot restore. Use [lab decision](debian-client-lab-decision.md) and [runbook](debian-client-lab-runbook.md). G0 independently verified archive and exact final test evidence; G1 operator isolation/console/snapshot; G2 read-only collection and current explicit R2 lifecycle, static resolver ownership and expected identity/address. Stop for review. G3 separately approve only 0010/0030/0040 after native prerequisites. G4 actual runtime and static checks, G5 direct DNS and independent NSS, G6 reboot/rollback/restore. All G gates OPEN; no VM created. M6 network boot, M7 enrollment and V1.1 remain separate acceptance decisions.

No final I5 approval requested until current CI and documentation CI have succeeded. No main update, root execution, force push, rebase or actual lab action performed. External local logs and independently trusted delivery digest unavailable.
