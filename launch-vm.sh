#!/bin/bash
# Launch the OSI Linux VM with KVM, UEFI/OVMF, SPICE, and virtio devices.
set -euo pipefail

DISK="$HOME/VM/osi-linux.qcow2"
VARS="$HOME/VM/osi-linux-efi-vars.fd"
PIDFILE="/tmp/osi-vm.pid"
ISO="${1:-}"

# ── OVMF firmware detection ───────────────────────────────────────────────────
find_ovmf_code() {
    local p
    for p in \
        /usr/share/OVMF/OVMF_CODE.fd \
        /usr/share/OVMF/OVMF_CODE_4M.fd \
        /usr/share/edk2-ovmf/x64/OVMF_CODE.fd \
        /usr/share/edk2/ovmf/OVMF_CODE.fd \
        /usr/share/qemu/OVMF.fd \
        /usr/share/OVMF/x64/OVMF_CODE.fd; do
        [ -f "$p" ] && { echo "$p"; return; }
    done
}
find_ovmf_vars() {
    local p
    for p in \
        /usr/share/OVMF/OVMF_VARS.fd \
        /usr/share/OVMF/OVMF_VARS_4M.fd \
        /usr/share/edk2-ovmf/x64/OVMF_VARS.fd \
        /usr/share/edk2/ovmf/OVMF_VARS.fd \
        /usr/share/OVMF/x64/OVMF_VARS.fd; do
        [ -f "$p" ] && { echo "$p"; return; }
    done
}

OVMF_CODE=$(find_ovmf_code)
OVMF_VARS_TEMPLATE=$(find_ovmf_vars)

if [ -z "$OVMF_CODE" ]; then
    echo "ERROR: OVMF firmware not found. Install it first:"
    echo "  Debian/Ubuntu: sudo apt install ovmf"
    echo "  Arch:          sudo pacman -S edk2-ovmf"
    echo "  Fedora:        sudo dnf install edk2-ovmf"
    echo "  Void:          sudo xbps-install -y OVMF"
    exit 1
fi

[ -f "$DISK" ] || { echo "ERROR: Disk not found: $DISK"; echo "Run: sudo bash scripts/bootstrap.sh"; exit 1; }

# Per-VM EFI vars file — writable, persists boot entries between reboots
if [ ! -f "$VARS" ]; then
    if [ -n "$OVMF_VARS_TEMPLATE" ]; then
        cp "$OVMF_VARS_TEMPLATE" "$VARS" \
            || { echo "ERROR: Failed to copy OVMF vars template to $VARS"; exit 1; }
    else
        VARS=""
    fi
fi

# ── Stale PID check ───────────────────────────────────────────────────────────
if [ -f "$PIDFILE" ]; then
    OLD_PID=$(cat "$PIDFILE")
    if kill -0 "$OLD_PID" 2>/dev/null; then
        echo "VM already running (PID $OLD_PID). Kill it first: kill $OLD_PID"
        exit 1
    fi
    rm -f "$PIDFILE"
fi

# ── Build argument arrays — avoids word-splitting issues ─────────────────────
QEMU_ARGS=(
    -machine type=q35,accel=kvm
    -cpu host
    -smp cores=4,threads=2
    -m 8G
)

# UEFI firmware
if [ -n "$VARS" ]; then
    QEMU_ARGS+=(
        -drive "if=pflash,format=raw,unit=0,file=$OVMF_CODE,readonly=on"
        -drive "if=pflash,format=raw,unit=1,file=$VARS"
    )
else
    QEMU_ARGS+=( -bios "$OVMF_CODE" )
fi

# Disk
QEMU_ARGS+=(
    -drive "file=$DISK,if=none,id=disk0,format=qcow2"
    -device virtio-scsi-pci,id=scsi0
    -device scsi-hd,drive=disk0,bus=scsi0.0
)

# ISO (optional)
if [ -n "$ISO" ]; then
    [ -f "$ISO" ] || { echo "ERROR: ISO not found: $ISO"; exit 1; }
    QEMU_ARGS+=(
        -drive "file=$ISO,media=cdrom,readonly=on"
        -boot order=dc
    )
else
    QEMU_ARGS+=( -boot order=c )
fi

# Display — SPICE with virtio-vga for best guest performance
QEMU_ARGS+=(
    -device virtio-vga
    -spice port=5900,addr=127.0.0.1,disable-ticketing=on
)

# SPICE agent (clipboard sharing, resolution auto-resize)
QEMU_ARGS+=(
    -device virtio-serial-pci,id=virtio-serial0
    -chardev spicevmc,id=vdagent,name=vdagent
    -device virtserialport,chardev=vdagent,name=com.redhat.spice.0,bus=virtio-serial0.0
)

# QEMU guest agent (host can query guest info, graceful shutdown)
QEMU_ARGS+=(
    -chardev "socket,path=/tmp/qga.sock,server=on,wait=off,id=qga0"
    -device virtserialport,chardev=qga0,name=org.qemu.guest_agent.0,bus=virtio-serial0.0,nr=2
)

# Network — user-mode with SSH port forward
QEMU_ARGS+=(
    -netdev user,id=net0,hostfwd=tcp::2222-:22
    -device virtio-net-pci,netdev=net0
)

# USB — tablet for smooth mouse, plus USB redirection via SPICE
QEMU_ARGS+=(
    -usb
    -device usb-tablet
    -device usb-ehci,id=ehci0
    -chardev spicevmc,name=usbredir,id=usbredir0
    -device usb-redir,chardev=usbredir0,id=redirect0,bus=ehci0.0
    -chardev spicevmc,name=usbredir,id=usbredir1
    -device usb-redir,chardev=usbredir1,id=redirect1,bus=ehci0.0
)

# Audio — SPICE audio passthrough
QEMU_ARGS+=(
    -audiodev spice,id=snd0
    -device intel-hda
    -device hda-duplex,audiodev=snd0
)

# Daemonize
QEMU_ARGS+=(
    -daemonize
    -pidfile "$PIDFILE"
)

# ── Launch ────────────────────────────────────────────────────────────────────
echo "OVMF: $OVMF_CODE"
[ -n "$VARS" ] && echo "VARS: $VARS"
echo "Disk: $DISK"
echo ""

qemu-system-x86_64 "${QEMU_ARGS[@]}"

echo "VM started (PID $(cat "$PIDFILE"))."
echo "  Connect:  spicy -h 127.0.0.1 -p 5900"
echo "  SSH:      ssh -p 2222 localhost"
echo "  Stop:     kill $(cat "$PIDFILE")"
