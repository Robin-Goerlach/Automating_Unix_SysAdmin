# M1 integrations and future adapters

Deutsch: [Deutsche Fassung](integrations.de.md)

## MRTG

`bin/sasd-monitor-mrtg` generates a reviewable candidate configuration with one target per approved R2 host and metric. It maps each target to a local `sasd-mrtg-counter` input path and embeds no SNMP address, community, or credential. Existing `sasd-mrtg-counter` remains the four-line external-target adapter. `tests/m3-native.sh --require` executes a supplied MRTG binary and checks generated HTML/PNG artifacts; the recorded run used MRTG 2.17.10 from an isolated Debian package.

## RRDtool

The configured `rrd_dir` reserves a metric area. Existing `sasd-rrd-cycle` remains the explicit RRDtool wrapper. M1 does not create, update, overwrite, or delete RRD databases automatically. `tests/m3-native.sh --require` exercises create/update/fetch/graph with RRDtool 1.7.2; this is contemporary evidence, not historical compatibility.

## NetSaint, Nagios, and Ganglia

M1 owns the canonical local SASD state and history. Future adapters may export observations or import externally checked observations through bounded files. NetSaint belongs to the 1999 profile; Nagios and Ganglia are later-profile integrations. No native protocol, daemon, or alerting engine is implemented here.

## CFEngine

The R2 `sasd-site-audit` remains an independent local configuration check. M1 imports its four-column result like any other approved local observation. `bin/sasd-config-cfengine1` generates a small, warning-only CFEngine 1 candidate from the shared inventory and lifecycle state. Disabled and removed hosts are omitted. The candidate is profile-limited to 1999 and remains unverified until an original CFEngine 1.4 binary is run. The documented syntax basis is the historical `control`/`actionsequence`/`files` form; native parsing is not claimed. The generator does not install policies, start agents or repair systems. CFEngine 1 and the future CFEngine 2 adapter remain separate profiles.
