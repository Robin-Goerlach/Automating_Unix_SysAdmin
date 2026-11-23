# Scheduled operation notes

The historical environment relies on cron rather than a permanently running Python/Node monitoring service.

An operator might later schedule independent collectors at five-minute intervals and rebuild a static board, but cron entries must use absolute paths, non-root service accounts, a private spool and no inherited secrets. There is currently no automatic installer for system crontabs.

Before any scheduling: confirm collector runtime, error reporting, delay/jitter requirements, stale-state handling, locking and retention. In particular, multiple status writer instances may require a higher-level lock and batched atomicity; those tests are not complete.

Do not copy a sample cron line into production without those checks.
