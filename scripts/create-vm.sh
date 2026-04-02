#!/bin/bash
set -e
DISK="$HOME/VM/osi-linux.qcow2"
mkdir -p "$HOME/VM"
if [ -f "$DISK" ]; then
    echo "Disk already exists: $DISK"
    exit 1
fi
qemu-img create -f qcow2 "$DISK" 80G
echo "Created: $DISK"
qemu-img info "$DISK"
