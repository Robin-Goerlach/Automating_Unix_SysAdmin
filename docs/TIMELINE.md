# Historical compatibility profiles

Deutsch: [Deutsche Fassung](TIMELINE.de.md)

This document separates the **target period represented by a feature** from the actual date when SASD authored it. Development began in 2026. Git commit history is never backdated.

| Profile | Period | Technology available | Appropriate SASD work | Excluded until later |
| --- | --- | --- | --- | --- |
| P0 | 1985–1988 | Bourne shell, awk, sed, cron, syslog; Perl appears in 1987 | log summaries, passwd inventory, backups, system reports | CFEngine, MRTG, Big Brother, RRD |
| P1 | 1989–1994 | Perl 4/5, early SSH and CFEngine 1 (from 1993) | more advanced scripts, access and file policy checks, optional CFEngine 1 | CFEngine 2, MRTG before 1995 |
| P2 | 1995–1997 | MRTG 1 (1995), Big Brother (1996), CFEngine 1 | SNMP/MRTG targets, simple status monitoring, role policies | RRDtool 1.0, Nagios |
| P3 | 1998–1999 | RRDtool development and release (1999), NetSaint in 1999 | RRD history, offline status board, optional NetSaint-era integration | CFEngine 2, Nagios-branded components |
| P4 | 2002–2004 | CFEngine 2, Nagios name | CFEngine 2 configuration master, service checks, SSH restrictions | book-2009 procedures presented as 1999 |
| P5 | 2005–2009 | FAI/Kickstart/JumpStart and mature CFEngine 2; Ganglia/NRPE | multi-OS bootstrap, service stack, reporting, backup acceptance | retroactive historical claims |

## Sources and caveats

- CFEngine was initially released in 1993. https://cfengine.com/blog/2023/cfengine-3-23-released-anniversary/
- Archived GNU mirror lists cfengine-1.4.0 in June 1997 and cfengine-2.0.1 in April 2002. A mirror timestamp is corroborating archive evidence, not an exact original launch date: https://ftp4.gwdg.de/pub/gnu/ftp/pub/gnu/cfengine/
- MRTG 1.0 was released in spring 1995 according to its author: https://www.mrtg.org/mrtg/doc/mrtg-reference.en.html
- Big Brother v1.00 was documented on 31 December 1996: https://linuxgazette.net/issue15/bb-info.html
- A USENIX LISA '98 paper discusses the RRD development: https://www.usenix.org/legacy/event/lisa98/full_papers/oetiker/oetiker_html/oetiker.html
- RRDtool 1.0 release is generally dated to July 1999. https://jffnms.org/knowledge/history-of-open-source-network-management
- NetSaint (later Nagios) began in 1999; the Nagios name dates to 2002. https://www.nagios.org/about/history/

The exact age of a period-specific program and its availability on every targeted Unix platform still require per-version verification. In particular, modern CFEngine 3 policy syntax is not interchangeable with the earlier versions.

## Compatibility versus preservation

**Period-inspired** means selecting an interface and software family that existed in the period. **Period-validated** requires a successful test on a period OS and a documented binary/version combination. CI provides contemporary regression evidence only.

For original Unix variants, prioritize isolated KVM/QEMU guest systems with a host-only network and no connection to production services. Never weaken SSH or expose old services on a normal network simply to gain authenticity.

## Provisioning extension boundary

The M5 archive tools and M6/M7 offline preparation were authored in 2026 as later SASD extensions. A file-system TAR archive is not evidence of a period boot image. DHCP/dnsmasq, TFTP staging, Solaris JumpStart, Red Hat Kickstart and Debian FAI remain version-specific later-profile adapters; their candidate templates are not claims that the initial 1999 environment provided them. Native platform acceptance requires an exact binary, OS, isolated lab and recorded run.
