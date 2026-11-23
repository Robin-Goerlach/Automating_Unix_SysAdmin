# Host-side test harness; not required by the historical runtime.
.PHONY: test syntax
test: syntax
	sh tests/smoke.sh
	sh tests/classic.sh
syntax:
	@for x in bin/sasd-disk-watch bin/sasd-status-store bin/sasd-status-board bin/sasd-config-drift bin/sasd-mrtg-counter bin/sasd-passwd-audit bin/sasd-syslog-count bin/sasd-ntp-sources bin/sasd-cron-inspect; do perl -c $$x || exit 1; done
	@for x in bin/sasd-host-facts bin/sasd-rrd-cycle tests/smoke.sh tests/classic.sh examples/demo.sh; do sh -n $$x || exit 1; done
