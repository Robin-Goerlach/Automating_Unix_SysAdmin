# Host-side test harness; not required by the historical runtime.
.PHONY: test syntax release-test site-test integrated-site-lab deployment-test
test: syntax
	perl tests/docs-pairs.pl
	sh tests/smoke.sh
	sh tests/classic.sh
	sh tests/bb-hosts.sh
	sh tests/bigbrother.sh
	sh tests/bigsister.sh
	sh tests/r2-site.sh
	sh tests/cfengine1.sh
	sh tests/cfengine2.sh
	sh tests/m1-monitoring.sh
	sh tests/m2-enrollment.sh
	sh tests/m2-transport.sh
	sh tests/m2-ssh-integration.sh
	sh tests/m3-native.sh
	sh tests/m4-backup.sh
	sh tests/m4-operations.sh
	sh tests/m5-golden.sh
	sh tests/m6-netboot.sh
	sh tests/m7-postinstall.sh
	sh tests/deployment.sh
	sh examples/sasd-integrated-site-lab.sh
	sh install/debian-client/test.sh
deployment-test:
	sh tests/deployment.sh
site-test:
	sh tests/r2-site.sh
integrated-site-lab:
	sh examples/sasd-integrated-site-lab.sh
syntax:
	@perl tests/check-eol.pl bin/* tests/*.sh tests/*.pl examples/*.sh install/*.sh lib/SASD/*.pm site/*.tsv Makefile
	@perl -c tests/docs-pairs.pl
	@for x in bin/sasd-disk-watch bin/sasd-status-store bin/sasd-status-board bin/sasd-config-drift bin/sasd-mrtg-counter bin/sasd-passwd-audit bin/sasd-syslog-count bin/sasd-ntp-sources bin/sasd-cron-inspect bin/sasd-bb-hosts-lint bin/sasd-site-inventory bin/sasd-site-migrate bin/sasd-site-classes bin/sasd-site-audit bin/sasd-site-services bin/sasd-host-admin bin/sasd-site-config bin/sasd-site-consistency bin/sasd-config-deploy bin/sasd-monitor-config bin/sasd-monitor-hosts bin/sasd-monitor-import bin/sasd-monitor-auth-import bin/sasd-monitor-receive bin/sasd-monitor-cycle bin/sasd-monitor-report bin/sasd-monitor-mrtg bin/sasd-monitor-control bin/sasd-enrollment bin/sasd-node-status bin/sasd-node-send bin/sasd-status-import-bigbrother bin/sasd-status-import-bigsister bin/sasd-golden-audit bin/sasd-golden-catalog bin/sasd-netboot-config bin/sasd-config-cfengine1 bin/sasd-config-cfengine2 bin/sasd-config-bigbrother bin/sasd-config-bigsister lib/SASD/Monitor.pm; do perl -c $$x || exit 1; done
	@for x in bin/sasd-host-facts bin/sasd-rrd-cycle bin/sasd-monitor-backup bin/sasd-monitor-restore bin/sasd-golden-capture bin/sasd-golden-restore bin/sasd-netboot-stage bin/sasd-postinstall install/install-monitoring-server.sh install/install-sasd-client.sh tests/smoke.sh tests/classic.sh tests/bb-hosts.sh tests/bigbrother.sh tests/bigsister.sh tests/r2-site.sh tests/cfengine1.sh tests/cfengine2.sh tests/m1-monitoring.sh tests/m2-enrollment.sh tests/m2-transport.sh tests/m2-ssh-integration.sh tests/m3-native.sh tests/m4-backup.sh tests/m4-operations.sh tests/m5-golden.sh tests/m6-netboot.sh tests/m6-kvm-preflight.sh tests/m7-postinstall.sh tests/deployment.sh examples/demo.sh examples/monitoring-lab.sh examples/m2-enrollment-lab.sh examples/m5-golden-lab.sh examples/m6-netboot-lab.sh examples/m7-install-to-monitoring.sh examples/sasd-provisioning-lab.sh examples/sasd-integrated-site-lab.sh release/package-1.0.sh release/package.sh; do sh -n $$x || exit 1; done

release-test:
	@set -eu; tmp=$$(mktemp -d); trap 'rm -rf "$$tmp"' EXIT HUP INT TERM; \
	release/package.sh --version 1.1.0-dev --ref HEAD --out "$$tmp" --test; \
	release/package.sh --version 1.1.0-dev --ref HEAD --out "$$tmp/second" --test; \
	sha256sum -c "$$tmp/SHA256SUMS"; sha256sum -c "$$tmp/second/SHA256SUMS"; \
	cmp "$$tmp/sasd-1.1.0-dev-src.tar.gz" "$$tmp/second/sasd-1.1.0-dev-src.tar.gz"; \
	cmp "$$tmp/MANIFEST-1.1.0-dev.txt" "$$tmp/second/MANIFEST-1.1.0-dev.txt"; \
	git ls-tree -r --name-only HEAD > "$$tmp/expected"; \
	cmp "$$tmp/expected" "$$tmp/MANIFEST-1.1.0-dev.txt"; \
	printf 'reproducible-distribution=PASS\n'; \
	sha256sum "$$tmp/sasd-1.1.0-dev-src.tar.gz" "$$tmp/MANIFEST-1.1.0-dev.txt"
