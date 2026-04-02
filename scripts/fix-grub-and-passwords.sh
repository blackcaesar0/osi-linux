#!/bin/bash
# Run as root on the HOST to fix GRUB and reset passwords.
# Usage: sudo bash scripts/fix-grub-and-passwords.sh
set -euo pipefail

REAL_USER="${SUDO_USER:-$USER}"
DISK="${DISK_IMAGE:-/home/$REAL_USER/VM/osi-linux.qcow2}"
RAW="/tmp/osi-fix.raw"
MNT="/mnt/voidroot"
LOOP=""

step() { echo; echo "==> $*"; }

cleanup() {
    umount -R "$MNT" 2>/dev/null || true
    [ -n "$LOOP" ] && losetup -d "$LOOP" 2>/dev/null || true
    rm -f "$RAW" /tmp/grub-embed.cfg
}
trap cleanup EXIT

[ "$(id -u)" -eq 0 ] || { echo "ERROR: Run as root: sudo bash $0"; exit 1; }
[ -f "$DISK" ]        || { echo "ERROR: Disk not found: $DISK"; exit 1; }

command -v grub-mkstandalone &>/dev/null || \
    { echo "ERROR: grub-mkstandalone not found. Install grub2 or grub-efi tools on the host."; exit 1; }

# Collect passwords
echo -n "New root password: ";  read -rs ROOT_PASS;  echo
echo -n "Confirm: ";            read -rs ROOT_PASS2; echo
[ "$ROOT_PASS" = "$ROOT_PASS2" ] || { echo "Mismatch."; exit 1; }

echo -n "New user password: ";  read -rs USER_PASS;  echo
echo -n "Confirm: ";            read -rs USER_PASS2; echo
[ "$USER_PASS" = "$USER_PASS2" ] || { echo "Mismatch."; exit 1; }

step "Converting qcow2 to raw"
qemu-img convert -f qcow2 -O raw "$DISK" "$RAW"

step "Mounting"
LOOP=$(losetup --find --show --partscan "$RAW")
mkdir -p "$MNT"
mount "${LOOP}p2" "$MNT"
mount "${LOOP}p1" "$MNT/boot/efi"

UUID_ROOT=$(blkid -s UUID -o value "${LOOP}p2")
KVER=$(ls "$MNT/boot/" | grep '^vmlinuz-' | sort -V | tail -1 | sed 's/vmlinuz-//')

echo "    Kernel  : $KVER"
echo "    UUID    : $UUID_ROOT"

[ -z "$KVER" ] && { echo "ERROR: no kernel found in /boot"; exit 1; }
[ -f "$MNT/boot/initramfs-${KVER}.img" ] \
    || echo "WARNING: initramfs-${KVER}.img not found — boot will fail anyway"

step "Building standalone BOOTX64.EFI (config embedded, no external grub.cfg needed)"

cat > /tmp/grub-embed.cfg << GCFG
insmod part_gpt
insmod ext2
insmod search_fs_uuid
insmod linux

# Find the root partition by UUID — works regardless of disk numbering
search --no-floppy --fs-uuid --set=root ${UUID_ROOT}

set timeout=5
set default=0

menuentry "OSI Linux" {
    linux /boot/vmlinuz-${KVER} root=UUID=${UUID_ROOT} ro quiet
    initrd /boot/initramfs-${KVER}.img
}
GCFG

echo "--- embedded grub.cfg ---"
cat /tmp/grub-embed.cfg
echo "-------------------------"

mkdir -p "$MNT/boot/efi/EFI/BOOT"

grub-mkstandalone \
    --format=x86_64-efi \
    --output="$MNT/boot/efi/EFI/BOOT/BOOTX64.EFI" \
    "boot/grub/grub.cfg=/tmp/grub-embed.cfg"

echo "    BOOTX64.EFI written: $(ls -lh "$MNT/boot/efi/EFI/BOOT/BOOTX64.EFI")"

step "Resetting passwords"
mount --rbind /sys  "$MNT/sys"  && mount --make-rslave "$MNT/sys"
mount --rbind /dev  "$MNT/dev"  && mount --make-rslave "$MNT/dev"
mount --rbind /proc "$MNT/proc" && mount --make-rslave "$MNT/proc"

rm -f "$MNT/etc/passwd.lock" "$MNT/etc/shadow.lock" "$MNT/etc/gshadow.lock"
VM_USER=$(ls "$MNT/home/" | head -1)
ROOT_HASH=$(openssl passwd -6 "$ROOT_PASS")
USER_HASH=$(openssl passwd -6 "$USER_PASS")

chroot "$MNT" usermod -p "$ROOT_HASH" root \
    && echo "    root: OK" \
    || { echo "ERROR: failed to set root password"; exit 1; }

chroot "$MNT" usermod -p "$USER_HASH" "$VM_USER" \
    && echo "    $VM_USER: OK" \
    || { echo "ERROR: failed to set password for $VM_USER"; exit 1; }

step "Converting back to qcow2"
umount -R "$MNT"
losetup -d "$LOOP"
LOOP=""
qemu-img convert -f raw -O qcow2 "$RAW" "$DISK"
rm -f "$RAW"
chown "$REAL_USER:$REAL_USER" "$DISK"

echo ""
echo "==> Done. Run: ./launch-vm.sh"
