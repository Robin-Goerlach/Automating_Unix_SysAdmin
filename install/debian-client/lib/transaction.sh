#!/bin/sh
# Linux fixture transactions. Caller must hold an exclusive directory flock.
fixture_check() {
    uid=$(id -u); [ "$uid" -ne 0 ] || return 2
    case "$root" in /tmp/sasd-debian-lab.*) ;; *) return 2 ;; esac
    suffix=${root#/tmp/sasd-debian-lab.}
    case "$suffix" in ''|*[!a-zA-Z0-9]*) return 2 ;; esac
    private_dir "$root" && private_dir "$root/etc" || return 2
    regular "$root/.sasd-fixture" && [ "$(cat "$root/.sasd-fixture")" = SASD-DEBIAN-FIXTURE-1 ] || return 2
}
private_dir(){ [ -d "$1" ] && [ ! -L "$1" ] && [ "$(stat -c '%u:%a' -- "$1")" = "$uid:700" ]; }
regular(){ [ -f "$1" ] && [ ! -L "$1" ] && [ "$(stat -c '%u:%h' -- "$1")" = "$uid:1" ] && [ -r "$1" ]; }
# Keep the desired files as evidence, rather than consuming them on rename.
manifest(){
    private_dir "$1" || return 1
    for file in hostname hosts resolv.conf; do
        regular "$1/$file" || return 1
        digest=$(sha256sum < "$1/$file") || return 1
        printf '%s\t%s\t%s\n' "$file" "$(stat -c %a -- "$1/$file")" "${digest%% *}"
    done
}
# GNU sync with explicit path operands invokes fsync on files/directories.
# This is the fixture backend; never treat a successful call as a power-loss test.
sync_paths(){ /usr/bin/sync -- "$@"; }
sync_targets(){
    sync_paths "$root/etc/hostname" "$root/etc/hosts" "$root/etc/resolv.conf" || return 1
    sync_paths "$root/etc"
}
sync_prepared(){
    # Persist both snapshots and manifests before publishing APPLYING.
    sync_targets || return 1
    sync_paths "$work/original/hostname" "$work/original/hosts" "$work/original/resolv.conf" \
        "$work/check/etc/hostname" "$work/check/etc/hosts" "$work/check/etc/resolv.conf" \
        "$work/original.tsv" "$work/desired.tsv" "$root/.sasd-fixture" || return 1
    sync_paths "$work/original" "$work/check/etc" || return 1
    sync_paths "$work/check" || return 1
    sync_paths "$work" || return 1
    sync_paths "$root" || return 1
    sync_paths /tmp
}
state_set(){
    tmpstate=$(mktemp "$work/.state.XXXXXXXX") || return 1
    if ! printf '%s\n' "$1" > "$tmpstate" || ! sync_paths "$tmpstate" || ! mv -fT -- "$tmpstate" "$work/state"; then
        rm -f -- "$tmpstate"; return 1
    fi
    if ! sync_paths "$work"; then
        # Rename is visible but persistence is uncertain. Best-effort quarantine;
        # no later automatic apply/recovery may interpret this as committed.
        echo "JOURNAL SYNC UNCERTAIN: $work" >&2
        if tmpstate=$(mktemp "$work/.state.XXXXXXXX"); then
            if printf 'SYNC_FAILED\n' > "$tmpstate" && mv -fT -- "$tmpstate" "$work/state"; then
                sync_paths "$work/state" "$work" || true
            fi
            rm -f -- "$tmpstate"
        fi
        return 1
    fi
}
state_get(){ regular "$1/state" && cat "$1/state"; }
# Return the sole open transaction, or fail closed for ambiguous/unknown state.
# Legacy backups have no state; they are not recoverable by this protocol.
pending_transaction(){
    pending=
    for dir in "$root"/baseline.*; do
        [ -e "$dir" ] || [ -L "$dir" ] || continue
        private_dir "$dir" || return 2
        if [ ! -e "$dir/state" ] && [ ! -L "$dir/state" ]; then continue; fi
        state=$(state_get "$dir") || return 2
        case "$state" in
            PREPARING|COMMITTED|ROLLED_BACK) ;;
            APPLYING|ROLLING_BACK) [ -z "$pending" ] || return 2; pending=$dir ;;
            *) return 2 ;;
        esac
    done
    printf '%s\n' "$pending"
}
snapshot_valid(){
    regular "$work/original.tsv" && regular "$work/desired.tsv" && private_dir "$work/check" || return 1
    actual=$(manifest "$work/original") && [ "$actual" = "$(cat "$work/original.tsv")" ] || return 1
    actual=$(manifest "$work/check/etc") && [ "$actual" = "$(cat "$work/desired.tsv")" ] || return 1
}
same_file(){ cmp -s -- "$1" "$2" && [ "$(stat -c %u:%g:%a -- "$1")" = "$(stat -c %u:%g:%a -- "$2")" ]; }
restore_preflight(){
    snapshot_valid || return 1
    for name in hostname hosts resolv.conf; do
        regular "$root/etc/$name" || return 1
        if ! same_file "$root/etc/$name" "$work/original/$name" && ! same_file "$root/etc/$name" "$work/check/etc/$name"; then
            echo "RECOVERY CONFLICT: $name" >&2; return 1
        fi
    done
}
replace_file(){
    # Stage in the private target directory so rename is on the same filesystem.
    staged=$(mktemp "$root/etc/.sasd-replace.XXXXXXXX") || return 1
    if ! cp -p -- "$1" "$staged" || ! same_file "$1" "$staged" || ! sync_paths "$staged" || ! mv -fT -- "$staged" "$2"; then
        rm -f -- "$staged"; return 1
    fi
    sync_paths "$root/etc"
}
restore_transaction(){
    restore_preflight || return 1
    state_set ROLLING_BACK || return 1
    for name in hostname hosts resolv.conf; do
        if ! same_file "$root/etc/$name" "$work/original/$name"; then
            replace_file "$work/original/$name" "$root/etc/$name" || return 1
            echo "ROLLED BACK: $name" >&2
        fi
    done
    actual=$(manifest "$root/etc") && [ "$actual" = "$(cat "$work/original.tsv")" ] || return 1
    sync_targets || return 1
    state_set ROLLED_BACK
}
