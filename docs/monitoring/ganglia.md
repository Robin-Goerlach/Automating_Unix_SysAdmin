# Ganglia offline candidate

Deutsch: [Deutsche Fassung](ganglia.de.md)

Ganglia is a later profile, not part of the 1999 baseline. The selected research
target is Ganglia 3.1.1 (Wien), released in September 2008. The official
project archive lists 3.1.1 on 8 September 2008 and 3.1.2 on 28 January 2009;
the project history lists 3.1.0 and 3.1.1 in 2008. This establishes a concrete
period target, not native parser acceptance.

The historical architecture separates gmond on cluster nodes from gmetad on
aggregation nodes. gmond announces and receives cluster state over multicast or
unicast and exposes an XML view. gmetad polls data sources, aggregates XML and
traditionally stores numeric volatile metrics in RRDtool. Clusters can be
federated into grids.

`bin/sasd-config-ganglia` maps each enabled host to at most one
`ganglia-*` inventory group. Ambiguous memberships are rejected. Hosts
without one use the `default` candidate profile. Ordinary inventory groups
remain host groups. An explicitly supplied lifecycle file must be readable
and valid. Lifecycle is a sparse projection, so an unlisted host remains
enabled.

With one cluster, `--gmond-out gmond.conf` writes that file. With multiple
clusters it writes separate candidates such as `gmond.ganglia-west.conf`
and `gmond.ganglia-east.conf`, each with one cluster declaration and its
members. The deployment manifest includes the individual files.
`--gmetad-out` lists unresolved data sources as comments. Operators must
supply TCP endpoints and multicast or unicast channels from the actual
topology for native acceptance. Use a fresh staging directory after a
topology change. Deployment copies manifest entries and leaves obsolete
target files in place.

`bin/sasd-ganglia-metric --hosts FILE --roles FILE --input FILE` reads
seven-field synthetic TSV observations. `--state FILE` uses the same
lifecycle projection as the generator.

    host<TAB>cluster<TAB>epoch<TAB>metric<TAB>value<TAB>unit<TAB>type

| Metric | Unit | Type | Accepted range |
| --- | --- | --- | --- |
| `cpu` | `percent` | Gauge | 0 to 100, up to six fractional digits |
| `mem` | `bytes` | Gauge | 0 to 999999999999999, integer |
| `load` | `count` | Gauge | 0 to 999999, up to six fractional digits |
| `net_rx`, `net_tx` | `bytes` | Counter | 0 to 999999999999999, integer |

CPU utilization is a percentage. Load average is a process count according
to the source platform's load definition. Network values are absolute
counters. Deriving rates requires separate handling of deltas, time, wraps
and resets.

The batch limits are 262144 input bytes, 2048 bytes per line excluding LF,
and 4096 observations. Epochs must strictly increase within a batch for
each host and metric. A format, type, range or identity error rejects the
batch with no output. A valid batch emits the original fields preceded by
`OK` or `UNKNOWN` and followed by `FIXTURE`. Future observations and those
older than `--freshness SECONDS` (default 900) relative to `--now EPOCH` or
the current time yield `UNKNOWN`. The raw value in an UNKNOWN row is for
diagnostic use.

Historical sources reviewed:

- [Ganglia project release history](https://ganglia.github.io/blog/archives/)
- [Ganglia core release archive](https://sourceforge.net/projects/ganglia/files/ganglia%20monitoring%20core/)
- [Ganglia architecture description](https://github.com/fastly/ganglia/blob/master/ganglia.pod)
- [Ganglia project and BSD licence statement](https://github.com/ganglia)

The architecture source describes the product model; it is not evidence that
the generated candidate parses on 3.1.1. Native 3.1.1 execution, XML parser
acceptance, multicast/unicast transport, gmetad storage and RRD lifecycle are
NOT TESTED.
