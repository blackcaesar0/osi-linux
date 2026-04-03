#!/bin/bash
# ──────────────────────────────────────────────────────────────────────────────
# OSI Linux — Create a QEMU/KVM VM disk and boot the installer from ISO
# Usage: bash scripts/create-vm.sh <path-to-iso>
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

ISO="${1:-}"
DISK="${DISK_IMAGE:-$HOME/VM/osi-linux.qcow2}"
DISK_SIZE="${DISK_SIZE:-80G}"
VARS="$HOME/VM/osi-linux-efi-vars.fd"

if [ -z "$ISO" ]; then
    echo "Usage: bash scripts/create-vm.sh <path-to-iso>"
    echo ""
    echo "  This creates a qcow2 disk and boots the ISO installer."
    echo "  After installing, boot normally with: ./launch-vm.sh"
    echo ""
    echo "  Options (via environment):"
    echo "    DISK_IMAGE=~/VM/custom.qcow2  — custom disk path"
    echo "    DISK_SIZE=120G                 — custom disk size"
    exit 1
fi

[ -f "$ISO" ] || { echo "ERROR: ISO not found: $ISO"; exit 1; }

# Create disk
mkdir -p "$(dirname "$DISK")"
if [ -f "$DISK" ]; then
    echo "Disk already exists: $DISK"
    echo -n "Overwrite? [y/N] "; read -r CONFIRM
    [ "$CONFIRM" = "y" ] || [ "$CONFIRM" = "Y" ] || { echo "Aborted."; exit 0; }
    rm -f "$DISK" "$VARS"
fi

echo "==> Creating $DISK_SIZE disk at $DISK"
qemu-img create -f qcow2 "$DISK" "$DISK_SIZE"
qemu-img info "$DISK"

# Boot the installer
echo ""
echo "==> Launching VM from ISO for installation..."
echo "    After installing, shut down and boot normally with: ./launch-vm.sh"
echo ""
exec "$(dirname "$0")/../launch-vm.sh" "$ISO"
