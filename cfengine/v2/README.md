# CFEngine 2 candidate profile

This directory is a separate later-profile adapter for CFEngine 2. It consumes the shared SASD role and host inventory and the shared lifecycle-state parser; it does not reuse the CFEngine 1 profile.

`bin/sasd-config-cfengine2` accepts version profiles `2.0` and `2.1`, emits a small warning-only candidate, and excludes disabled or removed hosts. `--dry-run` is read-only. `--apply` writes only the requested candidate file with mode `0600`; it does not install a policy, start `cfagent`, contact a server, or repair a host.

The generated `control`, `classes` and `files` sections are an independently authored candidate for review. They are not native acceptance evidence. No exact CFEngine 2 binary, operating system, parser output, or service execution was available in this WSL work. Modern CFEngine 3 syntax must not be substituted silently.
