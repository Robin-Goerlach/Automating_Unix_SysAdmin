# Host-side test harness; not required by the historical runtime.
.PHONY: test syntax
test: syntax
	sh tests/smoke.sh
	sh tests/classic.sh
	sh tests/bb-hosts.sh
syntax:
	@# Unix shell parsers treat CRLF's carriage return as part of 'then'/'fi'.
	@# Detect local Windows checkout conversion before running shell syntax checks.
	@cr=$(printf '\r'); for x in bin/* tests/*.sh examples/*.sh Makefile; do \
	  [ -f "$x" ] || continue; \
	  if LC_ALL=C grep -q "$cr" "$x"; then \
	    printf 'ERROR: CRLF line endings in %s; convert to LF (see README)\n' "$x" >&2; \
	    exit 1; \
	  fi; \
	done
	@for x in bin/sasd-disk-watch bin/sasd-status-store bin/sasd-status-board bin/sasd-config-drift bin/sasd-mrtg-counter bin/sasd-passwd-audit bin/sasd-syslog-count bin/sasd-ntp-sources bin/sasd-cron-inspect bin/sasd-bb-hosts-lint; do perl -c $$x || exit 1; done
	@for x in bin/sasd-host-facts bin/sasd-rrd-cycle tests/smoke.sh tests/classic.sh tests/bb-hosts.sh examples/demo.sh; do sh -n $$x || exit 1; done
