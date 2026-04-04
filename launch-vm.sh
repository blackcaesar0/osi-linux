#!/bin/bash
# ──────────────────────────────────────────────────────────────────────────────
# OSI Linux — Launch VM with KVM, UEFI/OVMF, SPICE, and virtio devices
#
# Optimized for:
#   - Auto-resize (virtio-gpu + spice-vdagent)
#   - Host<>guest clipboard (spice-vdagent)
#   - Audio passthrough (intel-hda via SPICE)
#   - USB device passthrough (SPICE USB redirection)
#   - Fast boot (virtio-scsi, virtio-net, KVM)
#
# Environment overrides:
#   VM_CORES=4  VM_THREADS=2  VM_RAM=8G  DISK_IMAGE=~/VM/osi.qcow2
#   NO_GL=1     (disable GL, use manual SPICE connection)
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

DISK="${DISK_IMAGE:-$HOME/VM/osi-linux.qcow2}"
VARS="${DISK%.qcow2}-efi-vars.fd"
PIDFILE="/tmp/osi-vm.pid"
ISO="${1:-}"
VM_CORES="${VM_CORES:-4}"
VM_THREADS="${VM_THREADS:-2}"
VM_RAM="${VM_RAM:-8G}"
NO_GL="${NO_GL:-0}"

# ── OVMF firmware detection ───────────────────────────────────────────────────
find_ovmf_code() {
    local p
    for p in \
        /usr/share/OVMF/OVMF_CODE.fd \
        /usr/share/OVMF/OVMF_CODE_4M.fd \
        /usr/share/edk2-ovmf/x64/OVMF_CODE.fd \
        /usr/share/edk2/ovmf/OVMF_CODE.fd \
        /usr/share/qemu/OVMF.fd \
        /usr/share/OVMF/x64/OVMF_CODE.fd \
        /usr/share/edk2/x64/OVMF_CODE.fd \
        /usr/share/qemu/edk2-x86_64-code.fd \
        /run/libvirt/nix-ovmf/OVMF_CODE.fd; do
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
        /usr/share/OVMF/x64/OVMF_VARS.fd \
        /usr/share/edk2/x64/OVMF_VARS.fd \
        /usr/share/qemu/edk2-x86_64-vars.fd \
        /run/libvirt/nix-ovmf/OVMF_VARS.fd; do
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
    exit 1
fi

[ -f "$DISK" ] || { echo "ERROR: Disk not found: $DISK"; echo "Run: bash scripts/create-vm.sh <iso>"; exit 1; }

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

# ── Build argument arrays ────────────────────────────────────────────────────
QEMU_ARGS=(
    -machine type=q35,accel=kvm
    -cpu host
    -smp "cores=${VM_CORES},threads=${VM_THREADS}"
    -m "$VM_RAM"
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

# Disk — virtio-scsi with writeback cache and discard support
QEMU_ARGS+=(
    -drive "file=$DISK,if=none,id=disk0,format=qcow2,cache=writeback,discard=unmap"
    -device virtio-scsi-pci,id=scsi0
    -device scsi-hd,drive=disk0,bus=scsi0.0
)

# ISO (optional — for installation)
if [ -n "$ISO" ]; then
    [ -f "$ISO" ] || { echo "ERROR: ISO not found: $ISO"; exit 1; }
    QEMU_ARGS+=(
        -drive "file=$ISO,media=cdrom,readonly=on"
        -boot order=dc
    )
else
    QEMU_ARGS+=( -boot order=c )
fi

# ── Display — virtio-gpu + SPICE ────────────────────────────────────────────
# virtio-gpu (not QXL!) is required for proper auto-resize and GL.
QEMU_ARGS+=( -device virtio-gpu-pci )

if [ "$NO_GL" = "1" ]; then
    # No-GL mode: manual SPICE client connection
    QEMU_ARGS+=(
        -spice port=5900,addr=127.0.0.1,disable-ticketing=on
        -daemonize
        -pidfile "$PIDFILE"
    )
    DISPLAY_MODE="SPICE (no GL)"
else
    # GL mode: SPICE app opens automatically with GPU acceleration
    QEMU_ARGS+=( -display spice-app,gl=on )
    DISPLAY_MODE="virtio-gpu + SPICE (GL)"
fi

# ── SPICE agent channel (clipboard + resize events) ─────────────────────────
QEMU_ARGS+=(
    -device virtio-serial-pci,id=virtio-serial0
    -chardev spicevmc,id=vdagent,name=vdagent
    -device virtserialport,chardev=vdagent,name=com.redhat.spice.0,bus=virtio-serial0.0
)

# ── QEMU guest agent (graceful shutdown, host queries) ──────────────────────
QEMU_ARGS+=(
    -chardev "socket,path=/tmp/qga.sock,server=on,wait=off,id=qga0"
    -device virtserialport,chardev=qga0,name=org.qemu.guest_agent.0,bus=virtio-serial0.0,nr=2
)

# ── Network — virtio-net with SSH port forward ───────────────────────────────
QEMU_ARGS+=(
    -netdev user,id=net0,hostfwd=tcp::2222-:22
    -device virtio-net-pci,netdev=net0
)

# ── USB — tablet for smooth mouse + SPICE USB redirection ───────────────────
QEMU_ARGS+=(
    -usb
    -device usb-tablet
    -device usb-ehci,id=ehci0
    -chardev spicevmc,name=usbredir,id=usbredir0
    -device usb-redir,chardev=usbredir0,id=redirect0,bus=ehci0.0
    -chardev spicevmc,name=usbredir,id=usbredir1
    -device usb-redir,chardev=usbredir1,id=redirect1,bus=ehci0.0
)

# ── Audio — SPICE audio passthrough ──────────────────────────────────────────
QEMU_ARGS+=(
    -audiodev spice,id=snd0
    -device intel-hda
    -device hda-duplex,audiodev=snd0
)

# ── Balloon — dynamic memory management ─────────────────────────────────────
QEMU_ARGS+=( -device virtio-balloon-pci )

# ── RNG — fix entropy starvation in VM ───────────────────────────────────────
QEMU_ARGS+=(
    -object rng-random,filename=/dev/urandom,id=rng0
    -device virtio-rng-pci,rng=rng0,max-bytes=1024,period=1000
)

# ── Launch ────────────────────────────────────────────────────────────────────
echo "╔══════════════════════════════════╗"
echo "║       OSI Linux VM Launch        ║"
echo "╚══════════════════════════════════╝"
echo ""
echo "  OVMF:    $OVMF_CODE"
[ -n "$VARS" ] && echo "  VARS:    $VARS"
echo "  Disk:    $DISK"
echo "  RAM:     $VM_RAM"
echo "  CPU:     ${VM_CORES}c/${VM_THREADS}t"
echo "  Display: $DISPLAY_MODE"
echo ""

qemu-system-x86_64 "${QEMU_ARGS[@]}"

if [ "$NO_GL" = "1" ]; then
    echo "VM started (PID $(cat "$PIDFILE"))."
    echo ""
    echo "  Connect:  spicy -h 127.0.0.1 -p 5900"
    echo "  SSH:      ssh -p 2222 osi@localhost"
    echo "  Creds:    osi / osi"
    echo "  Stop:     kill $(cat "$PIDFILE")"
else
    echo "VM started. SPICE display should open automatically."
    echo ""
    echo "  SSH:      ssh -p 2222 osi@localhost"
    echo "  Creds:    osi / osi"
fi
echo ""
echo "  Clipboard: auto via SPICE — copy/paste between host and guest"
echo "  Resize:    drag the SPICE window edge — guest follows automatically"
echo ""
echo "  Troubleshooting:"
echo "    No GL?          NO_GL=1 ./launch-vm.sh"
echo "    Fix display:    run 'fix-display' in guest terminal"
echo "    Fix clipboard:  run 'fix-clipboard' in guest terminal"
