# Host-side test harness; not required by the historical runtime.
.PHONY: test syntax
test: syntax
	sh tests/smoke.sh
syntax:
	@for x in bin/sasd-disk-watch bin/sasd-status-store bin/sasd-status-board bin/sasd-config-drift bin/sasd-mrtg-counter; do perl -c $$x || exit 1; done
	@for x in bin/sasd-host-facts bin/sasd-rrd-cycle tests/smoke.sh; do sh -n $$x || exit 1; done
