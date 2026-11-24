# M2 enrollment and Unix node bootstrap

Deutsch: [Deutsche Fassung](enrollment.de.md)

M2 adds a bounded enrollment control plane to the M1 directory layout. It is deliberately an offline workflow: a client creates a request and a signed status payload, while an operator moves those files into the server's private runtime area. No listener, automatic registration, remote shell, or production installation is provided.

## Identity and lifecycle

The client generates an RSA SSH key with `ssh-keygen`. The public-key SHA-256 fingerprint is recorded in the request and becomes the approved host identity. A hostname, inventory address, role, or operating-system label is not cryptographic authentication.

The server stores requests and records below `var/enrollment/`:

    requests/HOST.request
    records/HOST.tsv
    replay/HOST.seq
    events.tsv

The lifecycle is `pending-approval`, `approved`, `active`, `rejected`, or `disabled`. The operator uses `sasd-enrollment` to import a request, list or check records, approve, reject, disable, re-enable, and inspect a host. Approval does not activate a host until a valid signed status payload is accepted.

## Client bootstrap

The disposable client installer recognizes Linux, FreeBSD, OpenBSD, NetBSD, SunOS, AIX, and HP-UX names reported by `uname`. It requires an explicit non-system prefix and `--apply` for writes:

    install/install-sasd-client.sh \
      --prefix /tmp/sasd-node \
      --host node.lab.invalid --role web --profile web \
      --expires-at 2000000000 --dry-run
    install/install-sasd-client.sh \
      --prefix /tmp/sasd-node \
      --host node.lab.invalid --role web --profile web \
      --expires-at 2000000000 --apply

The installer copies only the approved client tools, creates an unprivileged RSA identity, writes a request and creates a commented cron template. It never writes `/etc`, installs a package, enables cron, starts a service, or sends the request. The request is reviewed with the server command:

    bin/sasd-enrollment --dir PREFIX/var/enrollment \
      --action import-request --request /tmp/sasd-node/var/enrollment.request
    bin/sasd-enrollment --dir PREFIX/var/enrollment \
      --action approve --host node.lab.invalid --operator admin --at 1000

## Authenticated status payloads

The client preserves the existing four-column records:

    host<TAB>check<TAB>color<TAB>message

`bin/sasd-node-status` adds a signed `SASD-AUTH-1` header containing the approved host, a strictly increasing sequence, and a send timestamp. It signs the complete payload with the client SSH private key using the established `ssh-keygen -Y sign` mechanism. The server command `sasd-monitor-auth-import` verifies the signature against the approved public key, checks host and role/check applicability, expiry, maximum clock skew, and sequence replay before writing any M1 latest record.

    bin/sasd-node-status --host node.lab.invalid \
      --key /tmp/sasd-node/etc/identity --sequence 1 --sent-at 1000 \
      --input observations.tsv --out payload
    bin/sasd-monitor-auth-import --config PREFIX/etc/sasd-monitor.conf \
      --input payload --signature payload.sig --now 1100

This is a file-exchange test and staging contract, not proof of a secure network transport. A later deployment may carry the payload over an operator-controlled SSH channel, but must validate host keys, account restrictions, file permissions, and cleanup separately. The repository does not implement an SSH listener, `authorized_keys` command restriction, or arbitrary remote command path.

## Revocation and recovery

`disable` immediately prevents authenticated imports and makes the M1 cycle report the enrolled host as purple with an enrollment-disabled message. `enable` returns an unexpired record to `approved`; a new signed sequence is then required. Sequence numbers are retained across disable/enable to prevent replay of old payloads. Rejected hosts have no active enrollment record and cannot import status.

## Boundaries and diagnostics

The control plane uses private plain-text files and is intended for a trusted operator-owned prefix. It rejects unsafe identifiers, malformed keys, symlinked files, expired requests, expired approvals, invalid roles/checks, duplicate checks, stale timestamps, altered signatures, and replayed sequences. It does not solve hostile concurrent writers, compromised private keys, clock trust, key rotation, or remote transport authorization. An operator must remove or rotate a compromised client identity and issue a new request.

Run the complete offline demonstration with:

    examples/m2-enrollment-lab.sh

The negative and two-client regression is `tests/m2-enrollment.sh`. Both require `ssh-keygen`; they use temporary directories, no root privileges, and no network.
