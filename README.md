# SASD Automating Unix SysAdmin

**English (default)** | [Deutsch](README.de.md) | [Roadmap](docs/ROADMAP.md) | [Architecture](docs/ARCHITECTURE.md) | [Historical scope](docs/TIMELINE.md)

An independently developed SASD collection of Unix system-administration scripts and historically informed integration examples. The initial working profile represents a **late-1990s Unix site (target year: 1999)**, with development pathways for earlier Bourne-shell environments and later 2002–2009 infrastructure automation.

**This is a present-day educational and research project, not an unearthed original historical archive.** Its components are written independently. It is not an official CFEngine, MRTG, RRDtool, or Big Brother distribution, and it does not embed those projects' proprietary source code.

## What is already implemented

| File | Role | Effect |
| --- | --- | --- |
| bin/sasd-host-facts | Portable hostname and kernel/system identity | Read-only |
| bin/sasd-disk-watch | POSIX df -kP reader, traffic-light status records | Read-only |
| bin/sasd-config-drift | Compare reference files to a selected target tree | Read-only |
| bin/sasd-status-store | Store validated four-column status reports in local files | Explicit local spool write |
| bin/sasd-status-board | Render a status overview to static HTML | Optional output write |
| bin/sasd-mrtg-counter | Expose local interface counters in the MRTG external target four-line format | Read-only |
| bin/sasd-rrd-cycle | Optional RRDtool creation and update wrapper | Explicit local RRD write |
| bin/sasd-passwd-audit | Offline passwd account and UID audit (no hashes printed) | Read-only |
| bin/sasd-syslog-count | BSD syslog program frequency, no severity guessing | Read-only |
| bin/sasd-ntp-sources | Enumerate NTP servers/peers from a local config | Read-only |
| bin/sasd-cron-inspect | Inspect simple 5-field user cron schedules | Read-only |
| bin/sasd-bb-hosts-lint | Inspect a subset of historical bb-hosts inventory syntax, without network activity | Read-only |
| bin/sasd-site-inventory | Validate and query a fictional TSV host inventory | Read-only |
| bin/sasd-site-classes | Resolve roles to independent SASD selection classes | Read-only |
| bin/sasd-site-audit | Select a role manifest and delegate a read-only drift audit | Read-only |
| bin/sasd-monitor-config | Validate bounded central-monitor configuration | Read-only |
| bin/sasd-monitor-hosts | List and inspect monitored R2 hosts | Read-only |
| bin/sasd-monitor-import | Validate and store local status observations | Explicit local runtime write |
| bin/sasd-monitor-cycle | Derive freshness-aware state and bounded history | Explicit local runtime write |
| bin/sasd-monitor-report | Render the central state as static HTML | Optional output write |
| bin/sasd-monitor-mrtg | Generate a candidate MRTG configuration | Optional output write |

The SASD status protocol is deliberately **not Big Brother's wire protocol**. There is no daemon, listening socket, remote command execution, or root-required installer in this milestone. Optional tools require their original external programs and must be separately validated.

## Try the offline laboratory

On a Unix host with Perl and a POSIX-compatible shell:

    git clone https://github.com/Robin-Goerlach/Automating_Unix_SysAdmin.git
    cd Automating_Unix_SysAdmin
    make test

Generate sample alerts and a local status page:

    mkdir -p /tmp/sasd-unix-status
    ./bin/sasd-disk-watch --host lab-host --input fixtures/df/healthy.txt
    ./bin/sasd-status-store --spool /tmp/sasd-unix-status --input fixtures/status/disk.tsv
    ./bin/sasd-status-board --spool /tmp/sasd-unix-status --out /tmp/sasd-unix-status/index.html

Open the generated local HTML file. The example contains synthetic sample data and does not assert anything about your current host.

Compare the sample NTP configuration against a separately stored reference:

    ./bin/sasd-config-drift --root fixtures/config/actual --golden fixtures/config/golden --manifest fixtures/config/manifest.tsv

Get the external MRTG data lines:

    ./bin/sasd-mrtg-counter --input fixtures/mrtg/ifcounters.tsv

See [bigbrother/README.md](bigbrother/README.md) for the period-style host inventory and [mrtg/README.md](mrtg/README.md) for optional MRTG integration and [rrd/README.md](rrd/README.md) for RRDtool. For an end-to-end walkthrough, use examples/demo.sh.

The R2 site laboratory is under [site/README.md](site/README.md). It uses fictional `192.0.2.0/24` records, never performs DNS lookups, and connects role-specific manifests to the existing read-only `sasd-config-drift` checker. The CFEngine 1 files under [cfengine/v1](cfengine/v1/README.md) remain candidate templates pending native historical acceptance.

The M1 central monitoring laboratory is documented under [docs/monitoring/README.md](docs/monitoring/README.md). It installs into a disposable prefix, imports local four-column status records, derives stale/unknown state, retains bounded transitions, and writes static HTML. It does not expose a network service or implement secure enrollment; those belong to M2.

## Product direction

- 1980s layer: Bourne shell, sed, awk, cron, syslog and simple text inventories.
- Early/mid-1990s layer: Perl 4/5, host administration, backups, local policy checks, CFEngine 1 as an optional external system.
- Late-1990s layer: MRTG, RRDtool, Big-Brother-inspired independent status reporting, testable reference configurations.
- 2002–2009 layer: CFEngine 2, FAI/Kickstart/JumpStart, secure SSH, Apache distribution, Nagios/NRPE, Ganglia, source control, restore evidence and policy-based security.

Modules do not need a single mandatory shared framework. The internal differences should reflect actual use cases, but **never fictitious authorship, commits, dates, or claims of testing on systems we did not run**.

## Documentation and rights

The ideas are informed by Nate Campi and Kirk Bauer's *Automating Linux and Unix System Administration*, 2nd ed. (Apress, 2009), and by broader Unix administration practice. See [docs/BOOK-MAP.md](docs/BOOK-MAP.md) and [docs/PROVENANCE.md](docs/PROVENANCE.md) for the topical map, decisions, and copyright boundary. No book examples are licensed into this repository merely because the book is used as a reference.

This repository's original SASD-authored materials are licensed under [MIT](LICENSE); third-party software, names and documentation retain their own terms.

## Current limitations

CI tests run on a current Linux runner and demonstrate offline behavior only. CFEngine 1 syntax, real historical Perl interpreters, actual MRTG rendering and RRDtool database lifecycle are **not yet accepted on period operating systems**. Treat all example settings as laboratory material, not a production deployment guide.


### Unix line endings on Windows or WSL

All Unix source files use **LF**, not Windows **CRLF**, because POSIX `sh` interprets carriage returns literally. A CRLF file may fail with `Syntax error: end of file unexpected (expecting "then")` even when the visible `if`/`fi` syntax looks correct.

Git's [.gitattributes](.gitattributes) pins text checkouts to LF regardless of `core.autocrlf`. [.editorconfig](.editorconfig) requests LF for compatible editors. Existing local files that were checked out before these rules may still have CRLF until converted.

Check your local tree before making changes:

```sh
git status --short
file bin/sasd-host-facts
sed -n '1,20l' bin/sasd-host-facts
```

If `file` mentions CRLF or `sed` shows `\\r$`, normalize the affected shell scripts in your local clone without discarding unrelated source edits:

```sh
sed -i 's/\r$//' bin/sasd-host-facts
make test
```

If `make test` reports additional CRLF files, convert only those reported files in the same way. **Do not run `git reset --hard` or `git clean` to solve a line-ending problem**; they can destroy local work.
