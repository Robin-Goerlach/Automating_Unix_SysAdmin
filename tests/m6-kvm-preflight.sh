#!/bin/sh
set -eu

require=0
if [ "${1-}" = "--require" ]; then
    require=1
elif [ "$#" -gt 0 ]; then
    echo "usage: tests/m6-kvm-preflight.sh [--require]" >&2
    exit 2
fi

missing=""
for command_name in virsh qemu-system-x86_64 qemu-img dnsmasq tcpdump ssh; do
    if command -v "$command_name" >/dev/null 2>&1; then
        printf 'available=%s path=%s\n' "$command_name" "$(command -v "$command_name")"
    else
        printf 'missing=%s\n' "$command_name"
        missing="$missing $command_name"
    fi
done

if [ -e /dev/kvm ] && [ -r /dev/kvm ]; then
    echo 'kvm-device=readable'
else
    echo 'kvm-device=missing-or-not-readable'
    missing="$missing /dev/kvm"
fi

if command -v virsh >/dev/null 2>&1; then
    if virsh -c qemu:///system uri >/dev/null 2>&1; then
        echo 'libvirt-system=reachable'
    else
        echo 'libvirt-system=unreachable'
        missing="$missing libvirt-system"
    fi
fi

if [ -n "$missing" ]; then
    echo "M6 KVM preflight: SKIPPED (missing or unavailable:$missing)"
    if [ "$require" -eq 1 ]; then
        exit 2
    fi
    exit 0
fi

echo 'M6 KVM preflight: READY (no network, VM, or service changes performed)'
