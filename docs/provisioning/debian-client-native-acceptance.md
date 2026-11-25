# Native Debian baseline acceptance contract (M7-D.1e)

Deutsch: [Deutsche Fassung](debian-client-native-acceptance.de.md)

Status: **PREPARATION ONLY — native apply not implemented or authorized.** Modern Debian profile only; the historical path is unchanged. See [client design](debian-client.md).

## Diagnostic tool

native-preflight.pl is read-only and standalone. Invoke as an ordinary user with trusted PATH and trusted file trees. Explicit --live selects the running system; --root=ABSOLUTE_DIR selects a non-root fixture tree and never runs runtime commands. Both require --hostname=lowercase FQDN (R2 maximum 63 characters) and --address=canonical IPv4. These are expected values from the operator-selected R2 record, not a separate inventory authority. The tool does not validate the inventory itself. It does not authorize writes, even if every observed value matches.

Example with documentation-only values:

    perl install/debian-client/native-preflight.pl --live --hostname=node.lab.invalid --address=192.0.2.40

Only with a real, operator-approved lab name and expected address, append --probe-name=FQDN --probe-address=IPv4. This opts into hostname -f and getent ahostsv4, which may cause network name lookups according to local NSS policy. No such lookup by default. The NSS probe requires exactly one distinct expected IPv4; a multi-address service is not this contract. It is not direct DNS evidence: files, NIS, caches or other NSS sources can answer. direct-dns always reports NOT_RUN.

The versioned TSV report SASD-NATIVE-PREFLIGHT-1 contains check/status/value; control bytes and percent signs are percent-encoded. Exit 0 means diagnostics emitted, NOT that the system passed; exit 2 is invalid invocation. UNKNOWN, OUT_OF_SCOPE, DRIFT and NOT_RUN require review. A detected VM/container is not proof that it is disposable. No secrets, resolver file contents or command lines from process listings are collected; hostnames and IPs are still private operational data. Command stderr remains separate. Linux timeout bounds live commands; missing tools or systemd bus are unknown, not evidence of inactive services. The conventional os-release link is mapped within the selected tree; file content is parsed, never sourced. Only trusted fixture trees (including ancestors and mounts) are supported, not a sandbox for hostile paths.

Resolver ownership is a hint, not a decision. Recognized symlinks and comments indicate systemd-resolved, NetworkManager, resolvconf or dhclient. A regular unmarked resolv.conf is UNKNOWN_REGULAR; it may be generated or overwritten. Service activity is supplemental only. Do not replace or unlink a managed resolver, disable a network manager, or assume static ownership because a service is inactive.

## Acceptance gates

| Gate | Required evidence | Status |
|---|---|---|
| G0 | Full make test as non-root, complete archive extracted and exercised, review exact commit and SHA-256 independently | OPEN |
| G1 | Operator identifies disposable Debian VM, isolated lab network, working console, verified snapshot restore, no production data | OPEN |
| G2 | Record Debian release, kernel, package/tool versions, R2 selection, current addresses and resolver manager; preflight and policy reviewed | OPEN |
| G3 | Before native write implementation: explicit scope, trusted root-owned input, safe target ownership and links, manager-specific handling, exclusive lock, tested rollback and reboot behavior | OPEN |
| G4 | After future authorized write: correct static files, runtime hostname/FQDN, expected IPv4 present, no loss of management access | OPEN |
| G5 | Direct DNS A query to each required DNS server and independent NSS lookup using known lab record; wrong answer and unreachable server tested | OPEN |
| G6 | Repeat, induced failure, rollback, reboot and snapshot restoration; record results, no unverified task marked complete | OPEN |

First proposed native target: Debian 12 or 13 minimal VM with operator-proven static resolver ownership; choose one actual release and record it. No version is accepted yet. Managed resolver support is a separate integration, not a fallback to overwriting files. Native scope initially limited to identity and resolver policy; no network reconfiguration, service enablement, packages, firewall or central enrollment. No automatic escalation or native apply switch exists.

## Lab procedure (read-only until a reviewed native writer exists)

1. Obtain the reviewed branch commit, check archive integrity against an independently trusted digest, and run G0. Use disposable VM console and an isolated lab VLAN/network, not production. Record snapshot identifier and demonstrate restoration on a disposable clone.
2. Select the real R2 record and site policy. Record expected FQDN, IPv4, DNS servers and an operator-maintained single-A test record not supplied by local hosts/NIS. Do not use .invalid or RFC 5737 addresses as live targets.
3. Capture preflight and existing verify-baseline.sh output (drift/unknown is expected before configuration). Record resolver symlink target, package ownership, service state, DHCP hooks and relevant network manager configuration manually. A regular file alone cannot establish ownership. Keep evidence privately.
4. Check the runtime resolver and direct DNS separately. On a VM with approved DNS tooling already installed, substitute actual lab values in the following read-only commands. Inspect exit codes, response status, queried server, answer owner/type and exact expected address; a successful dig exit alone does not establish success.

       getent ahostsv4 "$PROBE"
       dig +time=2 +tries=1 @"$DNS1" "$PROBE." A

   Repeat against each required DNS server. Use a single-A record with no CNAME for this initial acceptance. Require NOERROR and exact expected A answer; repeat with a known negative record and an isolated unreachable test server, without disrupting actual networking. NSS and direct DNS success are separate evidence. No public DNS resolver is assumed or contacted by the preflight by default.
5. Stop before native mutation. Future native writer must pass G3, then repeat G4–G6 from the console. Do not use fixture-apply against /, and do not bypass fixture guards. Restore snapshot if runtime connectivity or recovery cannot be verified.

## Evidence and current test limits

Record UTC timestamp, exact commit, archive digest, VM snapshot ID, Debian/kernel/tool versions, operator, expected vs observed rows, command exit codes, original/desired/current file hashes and recovery outcome. Keep raw evidence locally, sanitize before sharing. Never infer native acceptance from synthetic fixtures or from a container. No production release until all gates are reviewed and accepted.

Local test-native-preflight.sh passed as nobody: static fixtures, resolver hints, invalid input, non-Debian/ambiguous release, unsafe links, unchanged source hashes and non-execution of os-release content. Syntax passed. A separate real read-only smoke run in the Debian 13 container as nobody emitted the actual environment, drift, unknown service states and container virtualization; no opt-in name lookup. Live DNS/NSS, native VM, full repository suite, archive and CI remain unverified.

## G5 preparation: direct DNS response verifier (M7-D.1e.2)

verify-dns.pl is a separate read-only probe for one operator-approved lab A record. No query is sent without explicit --live; --fixture=FILE parses synthetic dig output and never contacts a server. Both require --server=IPv4 --name=lowercase.fqdn --expected=IPv4. Use actual lab values, not the reserved example addresses. The native path requires /usr/bin/dig and /usr/bin/timeout already installed; no automatic package installation, no default resolver, no scanning. Example after selecting approved lab values:

    perl install/debian-client/verify-dns.pl --live --server="$DNS1" --name="$PROBE" --expected="$EXPECTED"

Repeat for each required resolver. The program invokes dig without a shell, ignores .digrc, uses an absolute query name, bounds execution and output, and requires a single response header, response flag, untruncated response, matching server/question, NOERROR and precisely one A answer for the requested owner and expected IPv4. CNAME and multiple-answer services are outside the first acceptance scope. It does not validate DNSSEC, server identity cryptographically, NSS behavior, or all DNS records. Its text parser is intentionally strict: unfamiliar output is not evidence. Run the independent NSS probe described above as well.

SASD-DNS-VERIFY-1 reports scope, server, name, expected, status and reason. Exit 0 with LIVE_DNS/MATCH is a point-in-time direct DNS observation only, not native acceptance. Exit 0 with FIXTURE_ONLY/FIXTURE_MATCH is synthetic evidence only. Exit 1 = mismatch, 2 = invalid input, 3 = unknown/tool failure or ambiguous context. The native preflight still reports direct-dns NOT_RUN because it does not invoke this separate opt-in tool. No verified-task ledger accepts either result yet. Keep reports private.

After the interrupted response, branch head 3d2453231e080b3396bb096dd51a50e8a0b4d51e was confirmed. Re-executed exact published preflight fixture tests and the new DNS parser tests as nobody in the local Debian 13 container. DNS fixture tests cover single-A match, wrong address, NXDOMAIN, SERVFAIL, answer count, CNAME, wrong server/question, truncation, duplicate response, empty output and invalid/mixed arguments. Perl syntax and missing-dig UNKNOWN/exit 3 verified. The container lacks dig, so no live DNS query occurred; real dig output compatibility, unreachable lab server, NSS, native VM and G0 full suite/archive remain open. G5 remains OPEN; no write authorization.

## G0 provisioning integration evidence (M7-D.1e.3)

The entire provisioning subtree at base commit 89ae7c13399cd20fc587b74f2a6ab616bfe51301 was reconstructed in the local Debian 13 container because direct GitHub clone still fails name resolution. The Git tree hash of all 144 files under install/debian-client (including all 116 real task scripts and executable bits) matched the GitHub tree exactly: e9fe44aec272690c79e1c5848307394559b4c041. The independent R2 validator blob also matched: 5a1b56ba793ae92b75a6fb13a9dbe00c2b3cd22c. No synthetic task replacements in this integration run.

Executed sh install/debian-client/test.sh as nobody (UID 65534), exit 0. All existing component suites, actual process interruption/recovery, real catalog and dispatcher, fixture transaction and offline diagnostics passed. Added test-archive.sh and reran the entire provisioning suite as nobody, exit 0. The new test builds and checksums an allowlisted archive, extracts it with original file permissions into a private temporary directory, compares all 134 archived regular files byte-for-byte and mode-for-mode with the source (including the canonical R2 validator), rejects unexpected file types and file inventory changes, then exercises the packaged full inventory-bound stage (116 result rows, 8 staged, verified prerequisites remain blocked), candidate hashes, grouped fixture apply and static verification, fixture preflight, DNS parser fixtures and refusal of native apply. The DNS test harness is copied into a separate temporary directory with the unpacked executable. No production configuration changed and no DNS traffic was generated. The archive checksum check here verifies transport consistency, not independent release authentication.

The first new archive test exposed a test assumption: non-root tar extraction under umask 077 removes group/other mode bits by default. Using --same-permissions in the private test directory permits exact mode comparison; this does not change the package or weaken its private extraction boundary. No runtime code changed. G0 provisioning component and offline archive exercise now have positive evidence, but G0 as a whole remains OPEN: repository-wide make test and independently trusted release digest/review are not completed. CI and native Debian VM acceptance remain open. No live apply authorization.
