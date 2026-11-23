# Technical architecture — 1999 profile

## System boundary

    POSIX df output / selected local reference files / counter sample
                    |
           independent SASD checkers
           /           |           \
       disk-watch   config-drift   mrtg-counter ----> optional MRTG
           |
     4-column SASD TSV
           |
       status-store ----> spool/*.status ----> status-board ----> static HTML
                                                   (no daemon)
           |
       future alert router (NOT implemented)

    counter stream ----> optional rrd-cycle ----> RRDtool archive

The layout intentionally avoids a mandatory shared library, database, agent framework or service manager. Historical Unix installations can use only the tools they need.

## Interfaces and status semantics

Checker output:

    host<TAB>check<TAB>color<TAB>message

- host: ASCII letter/digit first, followed by ASCII letter/digit/dot/underscore/hyphen, at most 63 characters.
- check: ASCII letter first, then ASCII letter/digit/underscore/hyphen, at most 32 characters.
- color: green, yellow, red or purple.
- message: single printable line of up to 240 bytes.

The store prepends local epoch seconds and creates per-host/check spool files. A reader treats entries older than the configured age as purple (unknown/stale). This is an original SASD contract; interoperability with BB/Hobbit/Xymon is not claimed.

Disk-watch input is a previously captured **POSIX df -kP** text file or stdin stream; the initial implementation does not invoke live df on its own. Different Unix df implementations must be captured and tested before claiming compatibility.

Config-drift manifest:

    relative_target_path<TAB>relative_golden_path

Both roots are selected by the operator. The first version compares bytes and reports OK / DRIFT / MISSING / UNKNOWN / UNSAFE. It does not change files. Exit codes: 0=no differences, 1=differences, 2=unknown or unsafe. Failure to open or parse is a nonzero error as well.

MRTG adapter input is a four-column TSV with inbound and outbound monotonically increasing counters, uptime and host; its output comprises the four lines required by MRTG's documented external target convention. It **does not** poll a router via SNMP.

RRDtool bridge accepts explicit create or update commands. No archival deletion, automatic file replacement or implicit create-on-update is performed.

## Operational workflow

1. Create an isolated working directory and regular input fixture.
2. Run a read-only collector, examine stdout and status.
3. Write a local status record as an unprivileged process.
4. Generate a static HTML report and inspect it locally.
5. Compare role-specific golden files against chosen lab targets.
6. Optionally feed validated counter files to MRTG and RRDtool.
7. For changes to actual hosts, first create a separate change plan and rollback record (not yet implemented).

## Boundaries and open risks

- Status-store uses exclusive temporary-file creation and rename but should not run in a directory writable by untrusted users; race-free replacement of an attacker-controlled final path is not formally proven.
- Status-board writes an explicitly chosen file. Do not run it as root or serve the generated HTML on an untrusted webserver without a separate access-control and exposure review.
- Config-drift reads chosen directories and rejects symlink final objects, but ancestor directory symlink traversal is not comprehensively prevented: use only trusted lab roots.
- No remote transport, authentication, encryption or conflict handling exists in the status format. Adding a TCP listener requires a new security design.
- The RRD bridge is useful only if an appropriate RRDtool is installed. A real historical target must be tested independently.
- A modern Linux CI job does not prove Solaris, AIX, HP-UX, IRIX, OpenBSD, FreeBSD or historical Perl support.

## Site layout plan

Classic deployment may eventually use /usr/local/sasd/bin and /usr/local/sasd/etc, but current code runs directly from the checkout and does not write to /etc or /usr/local. Configuration examples remain under cfengine/, mrtg/, rrd/ and etc/ in the repository.
