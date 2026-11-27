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

bin/sasd-config-ganglia derives actual cluster identities only from inventory
groups prefixed `ganglia-`. Ordinary groups such as `admin` and `lab` remain
host-group metadata and are not silently treated as clusters. Hosts without an
explicit Ganglia group use the documented `default` cluster. The generator
emits separate review files for gmond and gmetad, omits disabled and removed
hosts, and selects the monitoring host as the gmetad source when available.
The files are candidates only: SASD does not start a daemon, bind a port, join
multicast, or create an RRD.

bin/sasd-ganglia-metric validates a bounded synthetic TSV format:

    host  cluster  epoch  metric  value  unit  type

Supported metrics are cpu, mem, load, net_rx and net_tx; types are gauge and
counter. Invalid identities, values, duplicates, out-of-order observations,
future timestamps and stale observations are rejected or emitted as UNKNOWN.
This is an SASD fixture format, not Ganglia XML. XML parsing and native RRDtool
ingestion remain separate acceptance work.

Historical sources reviewed:

- [Ganglia project release history](https://ganglia.github.io/blog/archives/)
- [Ganglia core release archive](https://sourceforge.net/projects/ganglia/files/ganglia%20monitoring%20core/)
- [Ganglia architecture description](https://github.com/fastly/ganglia/blob/master/ganglia.pod)
- [Ganglia project and BSD licence statement](https://github.com/ganglia)

The architecture source describes the product model; it is not evidence that
the generated candidate parses on 3.1.1. Native 3.1.1 execution, XML parser
acceptance, multicast/unicast transport, gmetad storage and RRD lifecycle are
NOT TESTED.
