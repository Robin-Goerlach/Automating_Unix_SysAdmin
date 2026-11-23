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

See [mrtg/README.md](mrtg/README.md) for optional MRTG integration and [rrd/README.md](rrd/README.md) for RRDtool. For an end-to-end walkthrough, use examples/demo.sh.

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
