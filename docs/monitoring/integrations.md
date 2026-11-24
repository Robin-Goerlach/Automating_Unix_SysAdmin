# M1 integrations and future adapters

Deutsch: [Deutsche Fassung](integrations.de.md)

## MRTG

`bin/sasd-monitor-mrtg` generates a reviewable candidate configuration with one target per approved R2 host and metric. It maps each target to a local `sasd-mrtg-counter` input path and embeds no SNMP address, community, or credential. Existing `sasd-mrtg-counter` remains the four-line external-target adapter. Native MRTG parsing and graph generation are not claimed; run an optional version-specific test only when MRTG is explicitly installed.

## RRDtool

The configured `rrd_dir` reserves a metric area. Existing `sasd-rrd-cycle` remains the explicit RRDtool wrapper. M1 does not create, update, overwrite, or delete RRD databases automatically. A real RRDtool lifecycle requires separate version evidence.

## NetSaint, Nagios, and Ganglia

M1 owns the canonical local SASD state and history. Future adapters may export observations or import externally checked observations through bounded files. NetSaint belongs to the 1999 profile; Nagios and Ganglia are later-profile integrations. No native protocol, daemon, or alerting engine is implemented here.

## CFEngine

The R2 `sasd-site-audit` remains an independent local configuration check. M1 imports its four-column result like any other approved local observation. M1 does not emulate CFEngine classes or claim CFEngine 1 native execution.
