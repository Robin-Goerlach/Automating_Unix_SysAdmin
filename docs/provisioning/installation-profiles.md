# M6 installation profiles

Deutsch: [Deutsche Fassung](installation-profiles.de.md)

Installation profiles are controlled TSV input, not a second host database. The existing SASD inventory remains authoritative for the site's host role and monitoring profile; M6 host rows add only boot identity and network-installation data.

The `method` field is one of `image`, `jumpstart`, `kickstart` or `fai`. The profile names an image record, architecture, installation source, role, partition-layout description, postinstall path and SASD monitoring profile. It contains no password, private key, enrollment approval or secret.

The image SHA256 is a selection check. Before any future installation, the operator must additionally verify the actual source, target capacity, boot requirements and post-installation plan. A profile cannot approve M2 enrollment and cannot authorize a write to a system disk.

The templates in `site/install/adapters/` are version-labelled candidates. Their presence is not native acceptance. Exact OS, installer, source checksum, command output and cleanup evidence are required before a compatibility statement is added.
