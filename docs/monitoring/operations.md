# M4 routine operation and recovery

Deutsch: [Deutsche Fassung](operations.de.md)

## Maintenance and acknowledgement

The canonical M1 state remains authoritative. Operators can annotate a known window or problem without changing the health state:

    bin/sasd-monitor-control --config PREFIX/etc/sasd-monitor.conf \
      --action maintenance-add --host web.lab.invalid --check disk \
      --until 2000000000 --operator admin --reason "planned storage work"
    bin/sasd-monitor-control --config PREFIX/etc/sasd-monitor.conf \
      --action acknowledge --host web.lab.invalid --check disk \
      --until 2000000000 --operator admin --reason "incident accepted"

The cycle adds unexpired annotations to the operator message. Expiry is checked against the cycle's `--now` time. `list`, `maintenance-clear` and `acknowledgement-clear` provide review and removal. Files are rewritten under a private lock with atomic replacement. External mail/SMS delivery is not implied.

## Backup

Back up an installed prefix to a new, operator-protected archive:

    bin/sasd-monitor-backup --root /srv/sasd-monitor --out /srv/backup/sasd-monitor.tar

The archive contains configuration, inventory, status/history, metrics, reports, operation annotations, public enrollment records and generated MRTG configuration. The server's `var/enrollment/keys` directory and client private keys are intentionally excluded and require separate protected handling. Existing archives require `--force` explicitly.

## Restore

Restore only into a new destination:

    bin/sasd-monitor-restore --archive /srv/backup/sasd-monitor.tar \
      --dest /srv/sasd-monitor-restored

The restore validates an allowlist of archive paths, rejects traversal and symlinks, extracts to a temporary sibling, and refuses an existing destination. Inspect the restored configuration before replacing a live prefix through a separately reviewed administrator procedure. `tests/m4-backup.sh` covers successful restore, excluded private material, missing/corrupt archives and existing destinations.
