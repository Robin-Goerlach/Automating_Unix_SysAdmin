# M2.1 SSH transport

Deutsch: [Deutsche Fassung](transport.de.md)

The transport adapter carries an existing `SASD-AUTH-1` payload over an operator-configured OpenSSH service. It adds no listener, server-key generation, enrollment approval, or remote shell.

Use the client with explicit trust inputs:

    bin/sasd-node-send --server monitor.example.invalid --user sasd --port 22 \
      --identity /path/client/etc/identity --known-hosts /path/client/etc/known_hosts \
      --payload /path/status.payload --signature /path/status.payload.sig --dry-run

Use `--send` only after the server host key has been reviewed and installed in the dedicated `known_hosts` file. The command uses strict host-key checking, `IdentitiesOnly`, batch mode, no agent/connection forwarding, no PTY, and no arbitrary SSH options. Its only remote command is `sasd-monitor-receive --stdio`.

The payload and signature are framed on stdin with bounded byte lengths. The receiver rejects a mismatched host, malformed, oversized, truncated or trailing input, and anything rejected by the existing authenticated importer. A dry-run never contacts the network.

For each enrolled client, use an unprivileged account and an `authorized_keys` entry with a forced command binding the host and server configuration, for example:

    command="/srv/sasd/bin/sasd-monitor-receive --config /srv/sasd/etc/sasd-monitor.conf --host node.example.invalid --stdio",no-pty,no-agent-forwarding,no-port-forwarding,no-X11-forwarding ssh-rsa AAAA...

Review absolute paths, the fingerprint and modes before installation. The receiver invokes only `sasd-monitor-auth-import`; it does not execute client command text or paths. The installer never changes `sshd_config`, accounts, `authorized_keys`, `/etc` or cron. The server host key is a separate trust decision from the client's payload key. Never use `StrictHostKeyChecking=no` or a writable `known_hosts` file.

`tests/m2-transport.sh` verifies offline framing and rejection behavior. This checkout has `ssh` and `ssh-keygen`, but no `sshd`; a real restricted transfer and rejection test are therefore pending. Native acceptance needs an isolated disposable guest or explicitly authorized local `sshd`, exact version evidence, host-key setup, and one successful plus one rejected transfer.

The receiver serializes submissions with a private lock and stages files with exclusive creation and mode 0600. The authenticated importer remains authoritative for signatures, enrollment state, role/check applicability, expiry and sequence replay.
