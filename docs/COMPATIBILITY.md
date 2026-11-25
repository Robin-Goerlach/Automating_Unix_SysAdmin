# Compatibility evidence matrix

Deutsch: [Deutsche Fassung](COMPATIBILITY.de.md)

This table records evidence, not aspirations. A tool is not historically supported merely because its syntax resembles an older Unix command.

| Environment or dependency | Evidence currently available | Claim permitted | Remaining gate |
| --- | --- | --- | --- |
| WSL2 development host, Linux 5.15.167.4-microsoft-standard-WSL2, Perl 5.36.0 | Local `make test`, syntax checks and offline fixtures | Contemporary offline development baseline | Keep regression evidence current |
| GitHub Actions Ubuntu runner | Existing workflow and previously recorded successful run for the then-published commit | CI-verified only for that runner image and commit | Push current commits and record the new run |
| POSIX shell implementations | `sh -n` on the current host and offline shell tests | Shell syntax accepted by the current host | Run a named historical shell matrix |
| Perl 5.004 | No execution evidence; some utilities use later syntax such as defined-or and substitution-return forms | Not supported or claimed | Rewrite or test a deliberately bounded subset on Perl 5.004 |
| FreeBSD, OpenBSD, Solaris, AIX, HP-UX and other historical Unix guests | No native guest evidence in this session | Not historically verified | Run the named binaries and archive OS/tool versions and output |
| MRTG, RRDtool, CFEngine and SSH integrations | Offline adapters and negative tests; native tools are optional or unavailable | Candidate/offline behavior only | Exercise exact external versions in isolated labs |

The current matrix therefore closes no historical support claim. It makes the negative boundary explicit while network access, GitHub authentication, native tools and historical guests remain unavailable.
