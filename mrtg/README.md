# MRTG adapter: local counter input

MRTG permits an external command to return four lines: incoming counter, outgoing counter, uptime and device name. SASD's bin/sasd-mrtg-counter implements this **documented external interface**, without embedding SNMP libraries or copying MRTG code.

The proposed mrtg.cfg.example deliberately contains placeholders. Replace PATH_TO_CHECKOUT and PATH_TO_MRTG_WORKDIR with absolute paths in a disposable guest. Run the external command alone before invoking MRTG. The fixture represents cumulative byte counters, not bandwidth in bytes per second. MRTG computes rates by polling regularly.

    ./bin/sasd-mrtg-counter --input fixtures/mrtg/ifcounters.tsv

This is not an SNMP poller. Real router data acquisition and MRTG graph creation remain separate acceptance tasks. Do not use a real SNMP community string or production router until a restricted read-only poller has been reviewed.

Documentation: https://mrtg.org/mrtg/doc/mrtg-reference.en.html
