# M1 central monitoring server

Deutsch: [Deutsche Fassung](README.de.md)

M1 is an offline, directory-based monitoring server for the 1999 profile. It is a collection of independent Perl and POSIX shell commands, not a daemon or database-backed framework.

## Installation

Use a disposable prefix and require `--apply` for writes:

    install/install-monitoring-server.sh \
      --prefix /tmp/sasd-monitor-lab \
      --config site/monitoring.conf --dry-run
    install/install-monitoring-server.sh \
      --prefix /tmp/sasd-monitor-lab \
      --config site/monitoring.conf --apply

The installer copies approved SASD programs, the R2 inventory, checks, the configuration, and the shared parser. It refuses system prefixes and symlink path components, preserves existing regular files, and never installs packages or registers services.

## Runtime layout

The installed prefix contains `bin/`, `etc/`, `lib/SASD/`, `var/status/`, `var/history/`, `var/metrics/`, `var/reports/`, `share/mrtg/`, and `log/`. Runtime files are local and plain text. The installer uses a private umask; operators should keep the prefix writable only by the monitoring account.

## One cycle

An approved local producer emits the existing four-column SASD record:

    host<TAB>check<TAB>color<TAB>message

Import, classify freshness, and render a report:

    bin/sasd-monitor-import --config PREFIX/etc/sasd-monitor.conf --input observations.tsv --received-at 1000 --source local
    bin/sasd-monitor-cycle --config PREFIX/etc/sasd-monitor.conf --now 1100
    bin/sasd-monitor-report --config PREFIX/etc/sasd-monitor.conf --out PREFIX/var/reports/index.html

The M1 import step is local and authenticated only by the operator-selected input path. It is not a network protocol and is not an enrollment mechanism. It validates the existing `sasd-status-store` four-column contract but keeps its own latest record because receipt time and source are central-server fields; the existing status store remains independently usable at the edge.

Run `examples/monitoring-lab.sh` for the complete disposable demonstration.
