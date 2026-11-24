# M1 configuration reference

Deutsch: [Deutsche Fassung](configuration.de.md)

`site/monitoring.conf` is a bounded `key=value` file. Blank lines and comments are accepted. Unknown keys, duplicate keys, control characters, absolute paths, and unsafe path traversal are rejected. Values are not shell code and are never evaluated.

Required keys:

| Key | Meaning |
| --- | --- |
| `inventory`, `roles`, `checks` | R2 TSV inputs, relative to the configuration directory |
| `status_dir` | Latest imported reports and derived state directory |
| `history_file` | Bounded event history |
| `state_file` | Current derived state |
| `report_file` | Default static HTML destination |
| `mrtg_file` | Candidate generated MRTG configuration destination |
| `rrd_dir` | Metric sample/RRD area; no database is created automatically |
| `enrollment_dir` | Private M2 request, approval, replay and audit area |
| `profile` | Historical profile label, currently `1999` |
| `freshness` | Maximum report age in seconds before derived state becomes purple |
| `history_retention` | Maximum retained history records |
| `mrtg_command` | Approved local external-target helper path |

Validate without writing:

    bin/sasd-monitor-config --config site/monitoring.conf --check

Optional output reports MRTG and RRDtool availability. Missing optional binaries are reported as `SKIPPED`; they do not fail offline tests.
