# RRDtool archive experiment (1999 extension)

Deutsch: [Deutsche Fassung](README.de.md)

RRDtool can retain and consolidate periodic measurements independently of MRTG's HTML presentation. This module is intentionally a small command wrapper, not a reimplementation of RRDtool.

    ./bin/sasd-rrd-cycle create /tmp/sasd-traffic.rrd
    ./bin/sasd-rrd-cycle update /tmp/sasd-traffic.rrd 120000 340000
    rrdtool info /tmp/sasd-traffic.rrd

Create requires a nonexistent local file. Update requires an existing regular file and nonnegative integer cumulative counters. A 300-second step and COUNTER sources are used. For real rates, collect successive observations and understand counter reset and wraparound.

RRDtool itself must be installed separately. Current CI checks syntax but does not assert that a 1999 RRDtool executable or any actual graph is available.

Reference: https://oss.oetiker.ch/rrdtool/
