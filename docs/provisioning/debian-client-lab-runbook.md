# Debian client — first disposable VM runbook

Deutsch: [Deutsche Fassung](debian-client-lab-runbook.de.md)

Status: **initial collection only; no native write authorization**. See the [acceptance contract](debian-client-native-acceptance.md) and [session history](debian-client-session.md).

## 1. Build and record the reviewed candidate (G0)

On a trusted development machine, use a separate checkout of the explicitly reviewed full commit SHA from the current integration candidate, not the obsolete original feature branch or an unreviewed main head. Before any native write, satisfy the combined branch gates and lifecycle requirements in the [integration plan](debian-client-integration-plan.md). The [lab decision packet](debian-client-lab-decision.md) defines the staged authorization boundaries. Run as an ordinary user. Do not copy real site files into the repository.

    git status --short
    git rev-parse HEAD
    make test
    install/debian-client/package.sh /tmp/sasd-debian-release

Use a new output directory. Record the commit, test exit and full log, OS and tool versions. If a mandatory test fails or an optional test relevant to native acceptance is skipped, keep G0 open. The included SHA-256 checks transport consistency, not provenance. Independently review the actual source and verify the archive against an expected digest retained through a trusted separate channel before running its programs. Do not regard an unsigned checksum next to the archive as independent proof.

## 2. Prepare the first VM (G1)

Choose a new Debian 13 amd64 minimal KVM/libvirt guest on local ext4, initially one filesystem for /etc and /var. Debian 12 and XFS remain separate candidate profiles. Use isolated/host-only networking, no production credentials or mounts, no shared storage and no production DNS. Use an actual lab IPv4 and preexisting lab DNS policy; avoid choosing a managed resolver for the first static test. Do not disable a manager to make a check pass. Record the guest name, exact Debian and kernel versions, hypervisor, network isolation and disk layout. Ensure access through the VM console without network/DNS. Create a clean snapshot and test restoration before considering mutation. A VM detection result alone is insufficient.

Tools needed for the first collection: POSIX shell, Perl, Python 3, coreutils, util-linux (flock), iproute2, systemd utilities; dig only for optional DNS verification. Install needed packages as part of normal VM preparation, not by the provisioning scripts. Do not run fixture tests as root.

## 3. First collection (G2; no sudo)

Transfer the reviewed archive and the independently retained expected digest by the approved lab route. Verify it before extraction. In a private new working directory, extract as an ordinary user; preserve the original permissions for later release comparison. Do not extract over existing files or as root.

    umask 077
    mkdir -m 700 "$HOME/sasd-lab-first"
    cd "$HOME/sasd-lab-first"
    sha256sum /path/to/reviewed/sasd-debian-client.tar.gz
    # Compare the displayed hash independently; stop on mismatch.
    tar --same-permissions -xzf /path/to/reviewed/sasd-debian-client.tar.gz

In the same directory, create the three input files from actual, separately chosen lab values. The R2 host row has six tab-separated fields; empty groups are intentional. Use the following only after defining HOST (lowercase FQDN), ADDRESS (existing canonical IPv4), DNS1 (approved lab resolver), and DOMAIN (lab search domain):

    printf '%s\t%s\tdebian\tworkstation\t\tbaseline\n' "$HOST" "$ADDRESS" > hosts.tsv
    printf 'workstation\tsite_workstation\tmodern\troles/workstation.tsv\n' > roles.tsv
    printf 'dns1=%s\nsearch=%s\n' "$DNS1" "$DOMAIN" > site.conf

Run one collection command:

    ./debian-client/collect-native.sh --live --hostname="$HOST" \
        --inventory=hosts.tsv --roles=roles.tsv --site=site.conf

Exit 3 with COLLECTED_NOT_AUTHORIZED is expected. The printed report path is private; G2 will be BLOCKED for incomplete unprivileged attribute visibility or other open conditions. The absent native journal path is also expected at this first stage. No DNS probes by default. Do not initialize privileged state or change the resolver solely to clear a blocked result.

Review gates.tsv, commands.tsv, preflight.tsv, capabilities.tsv and the rehearsal change summary (if present). Retain originals privately. For remote review, share only relevant redacted status rows and exit codes, not entire inventories, original files, installation IDs or fingerprints. Verify the actual resolver owner separately, including DHCP hooks and manager configuration.

## 4. Stop and review before any privileged phase

The experimental native installer exists, but do not run it yet. First review G0–G2 and any failures; agree on the precise native initialization, independently reviewed root-owned release and authorization, identity enrollment and snapshot/recovery procedure. The current native CLI uses fixed paths /opt/sasd/debian-client and /var/lib/sasd/provisioning, and does not initialize them. Initial non-root collection must never be mistaken for approval. If the VM does not fit the first profile, report the blocker instead of weakening the checks.

Later acceptance must exercise static apply, verification, direct DNS/NSS, restart/runtime hostname, repeated apply, interrupted apply and recovery, and tested snapshot restore on the actual disposable guest. Committed rollback is not yet implemented; snapshot fallback is mandatory. Keep G3–G6 open until those observations exist. No production deployment.
