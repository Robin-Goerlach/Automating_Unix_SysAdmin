# Host-side test harness; not required by the historical runtime.
.PHONY: test syntax
test: syntax
	perl tests/docs-pairs.pl
	sh tests/smoke.sh
	sh tests/classic.sh
	sh tests/bb-hosts.sh
	sh tests/r2-site.sh
	sh tests/m1-monitoring.sh
	sh tests/m2-enrollment.sh
syntax:
	@perl tests/check-eol.pl bin/* tests/*.sh tests/*.pl examples/*.sh install/*.sh lib/SASD/*.pm site/*.tsv Makefile
	@perl -c tests/docs-pairs.pl
	@for x in bin/sasd-disk-watch bin/sasd-status-store bin/sasd-status-board bin/sasd-config-drift bin/sasd-mrtg-counter bin/sasd-passwd-audit bin/sasd-syslog-count bin/sasd-ntp-sources bin/sasd-cron-inspect bin/sasd-bb-hosts-lint bin/sasd-site-inventory bin/sasd-site-classes bin/sasd-site-audit bin/sasd-monitor-config bin/sasd-monitor-hosts bin/sasd-monitor-import bin/sasd-monitor-auth-import bin/sasd-monitor-cycle bin/sasd-monitor-report bin/sasd-monitor-mrtg bin/sasd-enrollment bin/sasd-node-status lib/SASD/Monitor.pm; do perl -c $$x || exit 1; done
	@for x in bin/sasd-host-facts bin/sasd-rrd-cycle install/install-monitoring-server.sh install/install-sasd-client.sh tests/smoke.sh tests/classic.sh tests/bb-hosts.sh tests/r2-site.sh tests/m1-monitoring.sh tests/m2-enrollment.sh examples/demo.sh examples/monitoring-lab.sh examples/m2-enrollment-lab.sh; do sh -n $$x || exit 1; done
