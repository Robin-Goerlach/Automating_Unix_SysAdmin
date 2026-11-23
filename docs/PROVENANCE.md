# Independent development and source provenance

## What this project is

SASD is authoring a new, stand-alone script collection in 2026 to explore classical Unix operational practice from the 1980s to 2009. Historical profiles refer to the chosen technical environment, *not* to the actual code's date, authorship or revision history. All Git metadata remains genuine.

## Reference material

- Nate Campi and Kirk Bauer, *Automating Linux and Unix System Administration*, Second Edition, Apress (2009), ISBN 978-1-4302-1059-7. Used to understand topic families such as CFEngine, bootstrap, installation, NTP, DNS, rsync, monitoring, backups and security.
- David N. Blank-Edelman, *Automating System Administration with Perl*, Second Edition (O'Reilly, 2009). Used as subject-level context for Perl system administration; no book source code transferred.
- SASD-Sysadmin/freeware, https://github.com/SASD-Sysadmin/freeware, considered as an independent inspiration for practical administrative needs. This repository does not contain a copied history or direct import of its code.

## Third-party product documentation

- CFEngine — https://docs.cfengine.com/
- GNU CFEngine archive index — https://ftp.gnu.org.uk/gnu/cfengine/ (lists cfengine-1.4.0.tar.gz dated 1997-06-12 and later releases).
- GNU CFEngine historical reference — https://www.gnu.org/software/cfengine/docs/cfengine-Reference.html (action-sequence and file-policy background; version scope must be checked before acceptance).
- MRTG external target reference — https://mrtg.org/mrtg/doc/mrtg-reference.en.html
- RRDtool — https://oss.oetiker.ch/rrdtool/
- Big Brother history — https://linuxgazette.net/issue15/bb-info.html
- Nagios history — https://www.nagios.org/about/history/

These links identify historical and technical background. They are not assertions of license compatibility or permission to redistribute third-party code.

## Authorship and rights policy

No copyrighted program listings, substantial prose, diagrams or distinctive sample infrastructure from the books should be reproduced. Each function should have an independent SASD problem statement, data contract and tests. External software remains external; its source and documentation use their own licenses. Avoid using third-party product names in ways implying affiliation or endorsement.

SASD-original project files use the repository's MIT license. An individually contributed or imported file requires a provenance and license review prior to inclusion.

## How to record a new feature

Record the feature's practical purpose, operating-system/period profile, independent implementation approach, authoring date, third-party interfaces and known compatibility tests. Never claim historical testing or publish staged screenshots as genuine 1990s evidence unless provenance is explicit.

## R2 CFEngine 1 research boundary

The R2 candidate uses the historically documented `cfagent.conf` and `actionsequence` shape because public reference material describes those interfaces and the archive index provides a dated 1.4.0 source archive. The archive was not imported into SASD, and no original binary was executed. The repository therefore records a candidate policy, not native CFEngine 1 compatibility. Modern CFEngine 3 and later CFEngine 2 syntax are not used as substitutes.
