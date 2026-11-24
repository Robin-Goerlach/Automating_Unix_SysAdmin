# Big Brother host inventory format, without reproducing Big Brother

Deutsch: [Deutsche Fassung](README.de.md)

A core early Big Brother site inventory convention was to identify hosts by address/name and append network checks or server roles after a # separator. This folder provides an **original illustrative configuration** using TEST-NET addresses and fictional .invalid names. It contains no Big Brother executables, source, authentication data, alert implementation or network packets.

    ./bin/sasd-bb-hosts-lint --input bigbrother/bb-hosts.example

The linter checks a small ASCII/IPv4 subset, prints only hostnames and addresses and makes no network connection. It does not prove acceptance by any particular Big Brother version. Install a properly licensed historical release in a disposable guest, verify the exact bb-hosts grammar using its original documentation, and independently perform a parser/test run before calling the example compatible.

For an operational **independent SASD** status collector, use bin/sasd-status-store and bin/sasd-status-board; their TSV format is not the BB wire protocol.

Historical background:
- https://linuxgazette.net/issue15/bb-info.html — late-1996 overview
- https://linuxgazette.net/issue15/bbartlg.html — 1997 historical article about configuration and service checks
- https://www.linux-magazin.de/ausgaben/2002/09/grosser-bruder/ — later operational review

Product marks, code and licenses are independent of this MIT-licensed SASD repository. Avoid exposing original Big Brother network daemons outside an isolated lab.
