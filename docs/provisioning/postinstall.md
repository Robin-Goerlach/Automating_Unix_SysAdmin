# M7 postinstallation and monitoring enrollment

Deutsch: [Deutsche Fassung](postinstall.de.md)

`bin/sasd-postinstall` consumes one validated M6 profile and one M5/M6 image catalog. It checks the selected image ID, optional expected image version and architecture, then delegates client installation to the existing `install/install-sasd-client.sh`.

Example:

```sh
bin/sasd-postinstall \
  --root /tmp/sasd-client-a \
  --profile-file profiles.tsv --images images.tsv \
  --image-version 1.0 --profile web-lab \
  --host client-a.lab.invalid --expires-at 2000000000 --dry-run
```

Use `--apply` only with a new disposable prefix. The tool writes a host name, a small postinstall record, a new SSH client identity and an enrollment request. It does not write production `/etc`, install a system service, install Cron, submit the request or approve monitoring. The installer retains its existing explicit apply boundary.

The monitoring handoff is unchanged:

1. Operator imports the request with `sasd-enrollment --action import-request`.
2. Operator reviews the host, role, profile, expiry and public-key fingerprint.
3. Operator explicitly approves or rejects the request.
4. The node creates signed status records with `sasd-node-status`.
5. The existing M2/M2.1 transport and `sasd-monitor-auth-import` validate and import them.

## Reinstallation and identity policy

Every postinstall run generates a new client identity. Copying a restored client prefix is rejected because the postinstall record and identity already exist. A new request for a hostname with an active or disabled enrollment record is rejected by the existing enrollment control plane; it cannot silently replace an approved key. Key rotation and compromised-key recovery require a separately designed operator procedure and are not claimed as automated M7 functionality.

`tests/m7-postinstall.sh` covers two simulated clients, unique identities, stale image-version rejection, secret-like profile rejection, clone rejection, approved status import, rejected status import and active-host reinstallation refusal. `examples/m7-install-to-monitoring.sh` is an offline handoff walkthrough.
