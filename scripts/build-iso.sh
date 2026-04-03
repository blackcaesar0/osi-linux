#!/bin/bash
# Run as root on the HOST to build a bootable hybrid ISO.
# Usage: sudo bash scripts/build-iso.sh [output.iso]
#
# The ISO is EFI+BIOS hybrid — can be written directly to USB with dd.
# See docs/build-iso.md for full prerequisites and troubleshooting.
set -euo pipefail

# Resolve the invoking user even under sudo
REAL_USER="${SUDO_USER:-$(logname 2>/dev/null || echo root)}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

# ── CONFIGURATION ─────────────────────────────────────────────────────────────
WORK_DIR="${WORK_DIR:-/tmp/osi-iso-work}"
OUTPUT_ISO="${1:-$REAL_HOME/VM/osi-linux-$(date +%Y%m%d).iso}"
REPO="${REPO:-https://repo-default.voidlinux.org/current}"
XBPS_DIR="$REAL_HOME/VM/bootstrap"
XBPS_STATIC="$XBPS_DIR/usr/bin/xbps-install.static"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ROOTFS="$WORK_DIR/rootfs"
ISO_STAGE="$WORK_DIR/iso"

step() { echo; echo "==> $*"; }

# ── Cleanup trap ──────────────────────────────────────────────────────────────
cleanup() {
    echo "==> Cleaning up bind mounts..."
    umount -R "$ROOTFS/sys"  2>/dev/null || true
    umount -R "$ROOTFS/dev"  2>/dev/null || true
    umount -R "$ROOTFS/proc" 2>/dev/null || true
}
trap cleanup EXIT

# ── Preflight checks ──────────────────────────────────────────────────────────
step "Checking prerequisites"
MISSING=()
for cmd in mksquashfs xorriso grub-mkrescue dracut curl; do
    command -v "$cmd" &>/dev/null || MISSING+=("$cmd")
done
if [ "${#MISSING[@]}" -gt 0 ]; then
    echo "ERROR: Missing required tools: ${MISSING[*]}"
    echo "       Install them on the host before running this script."
    echo "       See docs/build-iso.md for per-distro install instructions."
    exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: Run as root: sudo bash scripts/build-iso.sh"
    exit 1
fi

# ── Static xbps ───────────────────────────────────────────────────────────────
step "Ensuring static xbps is available"
mkdir -p "$XBPS_DIR"
if [ ! -f "$XBPS_STATIC" ]; then
    curl -fsSL https://repo-default.voidlinux.org/static/xbps-static-latest.x86_64-musl.tar.xz \
        | tar xJ -C "$XBPS_DIR"
fi

# ── Fresh rootfs ──────────────────────────────────────────────────────────────
step "Creating fresh rootfs at $ROOTFS"
rm -rf "$ROOTFS" "$ISO_STAGE"
mkdir -p "$ROOTFS" "$ISO_STAGE"

# Pre-seed xbps signing keys from the bootstrap cache so xbps-install does not
# prompt for interactive key import confirmation (breaks non-TTY/background runs)
if [ -d "$XBPS_DIR/var/db/xbps/keys" ]; then
    mkdir -p "$ROOTFS/var/db/xbps/keys"
    cp "$XBPS_DIR/var/db/xbps/keys/"* "$ROOTFS/var/db/xbps/keys/"
    echo "    Seeded xbps keys from $XBPS_DIR"
else
    echo "WARNING: No cached xbps keys found — xbps-install may prompt interactively."
    echo "         Run sudo bash scripts/bootstrap.sh first to populate the key cache."
fi

# ── Bootstrap ─────────────────────────────────────────────────────────────────
step "Bootstrapping Void Linux base system (takes several minutes)"
XBPS_ARCH=x86_64 "$XBPS_STATIC" -S -r "$ROOTFS" -R "$REPO" -y base-system

# ── Bind mounts ───────────────────────────────────────────────────────────────
step "Binding host filesystems"
mount --rbind /sys  "$ROOTFS/sys"  && mount --make-rslave "$ROOTFS/sys"
mount --rbind /dev  "$ROOTFS/dev"  && mount --make-rslave "$ROOTFS/dev"
mount --rbind /proc "$ROOTFS/proc" && mount --make-rslave "$ROOTFS/proc"
cp /etc/resolv.conf "$ROOTFS/etc/"

# ── In-chroot setup ───────────────────────────────────────────────────────────
step "Running base-setup.sh inside chroot"
cp "$PROJECT_DIR/scripts/base-setup.sh"    "$ROOTFS/tmp/"
cp "$PROJECT_DIR/scripts/desktop-setup.sh" "$ROOTFS/tmp/"
chroot "$ROOTFS" bash /tmp/base-setup.sh
chroot "$ROOTFS" bash /tmp/desktop-setup.sh

# ── Live user ─────────────────────────────────────────────────────────────────
step "Creating live user"
chroot "$ROOTFS" /bin/bash << 'LIVEUSER'
set -euo pipefail
if ! id osi &>/dev/null; then
    useradd -m -G wheel,audio,video,cdrom,input,network -s /bin/bash osi
fi
echo "osi:osi" | chpasswd
echo "root:root" | chpasswd
echo "osi ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/99-osi-nopasswd
chmod 0440 /etc/sudoers.d/99-osi-nopasswd
LIVEUSER

# ── Live boot initramfs ───────────────────────────────────────────────────────
step "Building live initramfs"

KVER=$(ls "$ROOTFS/lib/modules/" 2>/dev/null | sort -V | tail -1)
if [ -z "$KVER" ]; then
    echo "ERROR: No kernel found in rootfs."
    exit 1
fi
echo "    Kernel: $KVER"

# Void Linux's dracut does not ship the dmsquash-live module.
# Use the HOST dracut (with dracut-live installed) pointing at the rootfs
# kernel modules — this avoids the Void dracut limitation entirely.
if ! dracut --list-modules 2>/dev/null | grep -q dmsquash-live; then
    echo "    dmsquash-live not found on host — installing dracut-live..."
    apt-get install -y dracut-live 2>/dev/null \
        || dnf install -y dracut-live 2>/dev/null \
        || pacman -S --noconfirm dracut-live 2>/dev/null \
        || { echo "ERROR: Could not install dracut-live on host. Install it manually and re-run."; exit 1; }
fi

step "Building dracut live initramfs using host dracut"
# Exclude systemd modules — the host (Ubuntu) uses systemd but Void uses runit.
# Without this, dracut pulls in systemd-init/systemd-shutdown from the host
# which conflicts with the Void rootfs and causes immediate halt on boot.
dracut --force \
    --add "dmsquash-live" \
    --omit "systemd systemd-initrd systemd-networkd systemd-hostnamed systemd-resolved systemd-timedated systemd-tmpfiles systemd-journald systemd-sysctl systemd-modules-load systemd-vconsole-setup systemd-sysusers systemd-repart systemd-pcrphase systemd-udevd" \
    --kver "$KVER" \
    --kmoddir "$ROOTFS/lib/modules/$KVER" \
    --fwdir "$ROOTFS/lib/firmware" \
    --no-hostonly \
    "$ROOTFS/boot/initramfs-live.img"

# ── Locate kernel image ───────────────────────────────────────────────────────
VMLINUZ=$(ls "$ROOTFS/boot/vmlinuz-"* 2>/dev/null | sort -V | tail -1)
if [ -z "$VMLINUZ" ]; then
    echo "ERROR: No vmlinuz found under $ROOTFS/boot/"
    exit 1
fi

# ── Squashfs ──────────────────────────────────────────────────────────────────
step "Creating squashfs image (xz — this takes a while)"
mkdir -p "$ISO_STAGE/LiveOS"
mksquashfs "$ROOTFS" "$ISO_STAGE/LiveOS/squashfs.img" \
    -comp xz -Xdict-size 100% -noappend \
    -e "$ROOTFS/proc" \
    -e "$ROOTFS/sys" \
    -e "$ROOTFS/dev" \
    -e "$ROOTFS/tmp"

# ── ISO boot structure ────────────────────────────────────────────────────────
step "Assembling ISO boot structure"
mkdir -p "$ISO_STAGE/boot/grub"
cp "$VMLINUZ"                            "$ISO_STAGE/boot/vmlinuz"
cp "$ROOTFS/boot/initramfs-live.img"     "$ISO_STAGE/boot/initramfs.img"

cat > "$ISO_STAGE/boot/grub/grub.cfg" << 'GRUB'
set timeout=5
set default=0

menuentry "OSI Linux Live" {
    linux  /boot/vmlinuz root=live:CDLABEL=OSI_LIVE rd.live.image quiet
    initrd /boot/initramfs.img
}

menuentry "OSI Linux Live (verbose)" {
    linux  /boot/vmlinuz root=live:CDLABEL=OSI_LIVE rd.live.image
    initrd /boot/initramfs.img
}

menuentry "OSI Linux Live (RAM)" {
    linux  /boot/vmlinuz root=live:CDLABEL=OSI_LIVE rd.live.image rd.live.ram quiet
    initrd /boot/initramfs.img
}
GRUB

# ── Build ISO ─────────────────────────────────────────────────────────────────
step "Building hybrid ISO with grub-mkrescue"
mkdir -p "$(dirname "$OUTPUT_ISO")"
grub-mkrescue \
    --output="$OUTPUT_ISO" \
    "$ISO_STAGE" \
    -- \
    -volid "OSI_LIVE" \
    -joliet on \
    -rockridge on

chown "$REAL_USER:$REAL_USER" "$OUTPUT_ISO"

echo ""
echo "==> ISO ready: $OUTPUT_ISO"
echo "    Size: $(du -sh "$OUTPUT_ISO" | cut -f1)"
echo "    SHA256: $(sha256sum "$OUTPUT_ISO" | cut -d' ' -f1)"
echo ""
echo "    Test: qemu-system-x86_64 -cdrom $OUTPUT_ISO -m 4G -enable-kvm -boot d"
echo "    USB:  sudo dd if=$OUTPUT_ISO of=/dev/sdX bs=4M status=progress oflag=sync"
