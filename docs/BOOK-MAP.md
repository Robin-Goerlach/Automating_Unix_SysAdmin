# Research map: Campi/Bauer (2009) to original SASD work

Primary reference: Nate Campi and Kirk Bauer, *Automating Linux and Unix System Administration*, Second Edition, Apress (2009), ISBN 978-1-4302-1059-7. The book's contents, including example code, are copyrighted. This document is a **conceptual coverage map**, not a derivative implementation plan or a reproduction of book code.

The 2009 text was written well after the 1999 baseline. As a result, modules have been reassigned to an independent SASD evolution in historical sequence instead of preserving the original tutorial steps, names, hosts, directory trees or policy text.

| Book topic / chapter | Independent SASD need | Deliverable / module | Profile | Status |
| --- | --- | --- | --- | --- |
| 1: Automation fundamentals | Reusable site inventory and system roles | host-facts, site-inventory, site-classes | P0–P3 | Offline inventory and role selection implemented |
| 2: Practical automation | Predictable failure handling, idempotence | rollback protocol and negative tests | all | Early tests implemented; rollback planned |
| 3: SSH administration | Audited, restricted remote access | SSH key and trust-policy review | P4/P5 | Planned |
| 4: cfengine | Detect/configure desired local state | independent config-drift + role audit + optional CFEngine 1 policy | P1/P4 | Drift and role audit implemented; CFEngine lab example unverified |
| 5: Infrastructure bootstrap | Host onboarding and control of baseline files | host enrollment, role manifests and staging | P4/P5 | Planned |
| 6: Automated installation | Repeatable isolated Unix guest builds | separate FAI, Kickstart and JumpStart adapters | P4/P5 | Planned |
| 7: Shared infrastructure | NTP, DNS, accounts, mail | independent audit and distribution helpers | P1–P5 | NTP file comparison fixture; services planned |
| 8: Application distribution | Safe deployment and rollback | manifest comparator, staged rsync/NFS/Apache examples | P3–P5 | Comparator only; application deployment planned |
| 9: Status and logs | Useful operator status without a large platform | file spool, report generator, syslog parser | P0–P5 | First two implemented; syslog planned |
| 10: Monitoring | Services, network metrics, proper alerting | SASD status board, MRTG target, RRDtool bridge; later NetSaint/Nagios, Ganglia, NRPE | P2–P5 | Initial core implemented; original product integration unverified |
| 11: Maintenance/recovery | Config history, backups, restore evidence | backup inventory, controlled restore tests | P0–P5 | Planned |
| 12: Security | Least privilege, permitted processes and configuration checks | read-only permissions and service policy, controlled remediation | P1–P5 | Config drift implemented; remainder planned |
| Appendix A: Basic tools | Small understandable utilities | POSIX shell, sed, awk, Perl, man pages | all | Shell/Perl foundation present |
| Appendix B: CFEngine modules | Extend a policy engine without replacing it | optional externally executed policy helpers | P4/P5 | Planned |

## Deliberate SASD additions

These are independent product decisions, not book reproductions:

1. A self-contained late-1990s profile with offline fixtures and status snapshots.
2. A static status board whose feed is **original SASD four-column TSV**, not Big Brother's private server or network protocol.
3. A cross-generation time policy: CFEngine 1 first, CFEngine 2 later.
4. A documented portability and authenticity gate for historical Unixes.
5. An explicit distinction between site policy audit, actual repair and safe rollback.
6. A security rule that old network services remain confined to an isolated lab.

## Research workflow

For any candidate, record: historical release, user need, affected platform, proposed independent data contract, risks, acceptance tests, implementation status and any licensing concerns. Review the book for subject coverage, but design from the independently written requirements and public vendor documentation.

Do not transfer names, prose, exact file layouts, sample IP blocks, sample company infrastructure, policy bodies or source listings from the book into SASD merely to make coverage look complete.
