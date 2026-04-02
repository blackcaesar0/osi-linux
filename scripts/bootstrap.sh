#!/bin/bash
# Run as root on the HOST to bootstrap Void Linux into a qcow2 disk.
# Usage: sudo bash scripts/bootstrap.sh
set -euo pipefail

# Resolve the invoking user's home directory even under sudo
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

# ── CONFIGURATION — override via environment variables ────────────────────────
DISK_SIZE="${DISK_SIZE:-80G}"
VM_HOSTNAME="${VM_HOSTNAME:-osi}"
DISK="${DISK_IMAGE:-$REAL_HOME/VM/osi-linux.qcow2}"
DISK_RAW="${DISK%.qcow2}.raw"
MNT="/mnt/voidroot"
REPO="https://repo-default.voidlinux.org/current"
XBPS_DIR="$REAL_HOME/VM/bootstrap"
XBPS_STATIC="$XBPS_DIR/usr/bin/xbps-install.static"

step() { echo; echo "==> $*"; }

# ── Cleanup trap ──────────────────────────────────────────────────────────────
LOOP=""
cleanup() {
    echo "==> Cleaning up..."
    sync
    umount -R "$MNT"     2>/dev/null || true
    [ -n "$LOOP" ] && losetup -d "$LOOP" 2>/dev/null || true
    rm -f "$DISK_RAW"
}
trap cleanup EXIT

# ── Preflight checks ──────────────────────────────────────────────────────────
for cmd in qemu-img losetup parted mkfs.fat mkfs.ext4 curl blkid udevadm grub-mkstandalone; do
    command -v "$cmd" &>/dev/null || { echo "ERROR: $cmd not found. Install it first."; exit 1; }
done

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: Run as root: sudo bash scripts/bootstrap.sh"
    exit 1
fi

# ── Detect host keyboard layout ───────────────────────────────────────────────
detect_keymap() {
    local km
    km=$(localectl status 2>/dev/null | awk '/X11 Layout/{print $3}')
    [ -n "$km" ] && { echo "$km"; return; }
    km=$(grep -i '^KEYMAP=' /etc/vconsole.conf 2>/dev/null | cut -d= -f2 | tr -d '"')
    [ -n "$km" ] && { echo "$km"; return; }
    km=$(grep '^XKBLAYOUT=' /etc/default/keyboard 2>/dev/null | cut -d= -f2 | tr -d '"')
    [ -n "$km" ] && { echo "$km"; return; }
    echo "us"
}
DETECTED_KEYMAP=$(detect_keymap)

# ── Collect user input up front ───────────────────────────────────────────────
step "Configure the new system"
echo -n "Username: "; read -r VM_USER
[ -n "$VM_USER" ] || { echo "Username cannot be empty."; exit 1; }

echo -n "Keyboard layout [$DETECTED_KEYMAP]: "; read -r KM_INPUT
VM_KEYMAP="${KM_INPUT:-$DETECTED_KEYMAP}"

echo -n "Root password: "; read -rs ROOT_PASS; echo
echo -n "Confirm root password: "; read -rs ROOT_PASS2; echo
[ "$ROOT_PASS" = "$ROOT_PASS2" ] || { echo "Passwords do not match."; exit 1; }

echo -n "Password for '$VM_USER': "; read -rs VM_PASS; echo
echo -n "Confirm password: "; read -rs VM_PASS2; echo
[ "$VM_PASS" = "$VM_PASS2" ] || { echo "Passwords do not match."; exit 1; }

# ── Step 1: static xbps ───────────────────────────────────────────────────────
step "Downloading static xbps binary"
mkdir -p "$XBPS_DIR"
if [ ! -f "$XBPS_STATIC" ]; then
    curl -fsSL https://repo-default.voidlinux.org/static/xbps-static-latest.x86_64-musl.tar.xz \
        | tar xJ -C "$XBPS_DIR"
fi
echo "OK: $XBPS_STATIC"

# ── Step 2: create raw disk ───────────────────────────────────────────────────
step "Creating raw disk image ($DISK_SIZE)"
mkdir -p "$REAL_HOME/VM"
rm -f "$DISK_RAW"
qemu-img create -f raw "$DISK_RAW" "$DISK_SIZE"

# ── Step 3: loop device ───────────────────────────────────────────────────────
step "Attaching loop device"
LOOP=$(losetup --find --show --partscan "$DISK_RAW")
udevadm settle
echo "Loop device: $LOOP"
lsblk "$LOOP"

# ── Step 4: partition ─────────────────────────────────────────────────────────
step "Partitioning disk (GPT: 512M EFI + rest root)"
parted -s "$LOOP" mklabel gpt
parted -s "$LOOP" mkpart EFI  fat32 1MiB 513MiB
parted -s "$LOOP" set 1 esp on
parted -s "$LOOP" mkpart root ext4  513MiB 100%
udevadm settle
lsblk "$LOOP"

# ── Step 5: format ────────────────────────────────────────────────────────────
step "Formatting partitions"
mkfs.fat -F32 -n EFI     "${LOOP}p1"
mkfs.ext4 -L voidroot -F "${LOOP}p2"

# ── Step 6: mount ─────────────────────────────────────────────────────────────
step "Mounting"
mkdir -p "$MNT"
mount "${LOOP}p2" "$MNT"
mkdir -p "$MNT/boot/efi"
mount "${LOOP}p1" "$MNT/boot/efi"

# ── Step 7: bootstrap ─────────────────────────────────────────────────────────
step "Bootstrapping Void Linux base system (this will take a few minutes)"
XBPS_ARCH=x86_64 "$XBPS_STATIC" -S -r "$MNT" -R "$REPO" -y base-system

# ── Step 8: bind mounts ───────────────────────────────────────────────────────
step "Binding host filesystems for chroot"
mount --rbind /sys  "$MNT/sys"  && mount --make-rslave "$MNT/sys"
mount --rbind /dev  "$MNT/dev"  && mount --make-rslave "$MNT/dev"
mount --rbind /proc "$MNT/proc" && mount --make-rslave "$MNT/proc"
cp /etc/resolv.conf "$MNT/etc/"

# ── Step 9: configure inside chroot ──────────────────────────────────────────
step "Configuring system inside chroot"

UUID_ROOT=$(blkid -s UUID -o value "${LOOP}p2")
UUID_EFI=$(blkid  -s UUID -o value "${LOOP}p1")

chroot "$MNT" /bin/bash << CHROOT
set -euo pipefail

chown root:root /
chmod 755 /

ln -sf /usr/share/zoneinfo/UTC /etc/localtime
echo "$VM_HOSTNAME" > /etc/hostname

echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "en_US.UTF-8 UTF-8" >> /etc/default/libc-locales
xbps-reconfigure -f glibc-locales

cat > /etc/rc.conf << RC
TIMEZONE="UTC"
KEYMAP="$VM_KEYMAP"
HARDWARECLOCK="UTC"
RC

# X11 keyboard layout — matches the console keymap
mkdir -p /etc/X11/xorg.conf.d
cat > /etc/X11/xorg.conf.d/00-keyboard.conf << KBEOF
Section "InputClass"
    Identifier "system-keyboard"
    MatchIsKeyboard "on"
    Option "XkbLayout" "$VM_KEYMAP"
EndSection
KBEOF

cat > /etc/fstab << FSTAB
UUID=$UUID_ROOT /         ext4  defaults             0 1
UUID=$UUID_EFI  /boot/efi vfat  defaults             0 2
tmpfs           /tmp      tmpfs defaults,nosuid,nodev 0 0
FSTAB

xbps-install -y sudo 2>/dev/null || true
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel

useradd -m -G wheel,audio,video,cdrom,input,network -s /bin/bash "$VM_USER"

xbps-install -y grub-x86_64-efi efibootmgr

# Ensure dracut generates an initramfs for the installed kernel
xbps-reconfigure -f linux*

CHROOT

# Build a standalone BOOTX64.EFI with the grub config embedded inside the binary.
# grub-install inside a loop-device chroot embeds wrong device paths.
# grub-mkstandalone on the host produces a single self-contained EFI binary
# that needs no external grub.cfg file — most reliable approach.
KVER=$(ls "$MNT/boot/" | grep '^vmlinuz-' | sort -V | tail -1 | sed 's/vmlinuz-//')
[ -z "$KVER" ] && { echo "ERROR: no kernel found in $MNT/boot/"; exit 1; }

if [ ! -f "$MNT/boot/initramfs-${KVER}.img" ]; then
    echo "WARNING: no initramfs for $KVER — trying to regenerate..."
    chroot "$MNT" dracut --force /boot/initramfs-${KVER}.img "$KVER" 2>/dev/null || true
fi
[ -f "$MNT/boot/initramfs-${KVER}.img" ] || { echo "ERROR: initramfs generation failed for $KVER"; exit 1; }

cat > /tmp/grub-embed.cfg << GCFG
insmod part_gpt
insmod ext2
insmod search_fs_uuid
insmod linux

search --no-floppy --fs-uuid --set=root ${UUID_ROOT}

set timeout=5
set default=0

menuentry "OSI Linux" {
    linux /boot/vmlinuz-${KVER} root=UUID=${UUID_ROOT} ro quiet
    initrd /boot/initramfs-${KVER}.img
}
GCFG

mkdir -p "$MNT/boot/efi/EFI/BOOT"
grub-mkstandalone \
    --format=x86_64-efi \
    --output="$MNT/boot/efi/EFI/BOOT/BOOTX64.EFI" \
    "boot/grub/grub.cfg=/tmp/grub-embed.cfg"

rm -f /tmp/grub-embed.cfg
echo "    Kernel  : $KVER"
echo "    UUID    : $UUID_ROOT"
echo "    BOOTX64.EFI: $(ls -lh "$MNT/boot/efi/EFI/BOOT/BOOTX64.EFI")"

# Set passwords outside the heredoc — avoids shell interpretation of special
# characters like $, \, ` that would corrupt passwords set inside a heredoc
rm -f "$MNT/etc/passwd.lock" "$MNT/etc/shadow.lock" "$MNT/etc/gshadow.lock"
ROOT_HASH=$(openssl passwd -6 "$ROOT_PASS")
VM_HASH=$(openssl passwd -6 "$VM_PASS")
chroot "$MNT" usermod -p "$ROOT_HASH" root        || { echo "ERROR: failed to set root password";     exit 1; }
chroot "$MNT" usermod -p "$VM_HASH"   "$VM_USER"  || { echo "ERROR: failed to set $VM_USER password"; exit 1; }

# ── Step 10: convert to qcow2 ────────────────────────────────────────────────
step "Converting raw image to qcow2"
sync
umount -R "$MNT"
losetup -d "$LOOP"
LOOP=""
qemu-img convert -f raw -O qcow2 "$DISK_RAW" "$DISK"
rm -f "$DISK_RAW"
chown "$REAL_USER:$REAL_USER" "$DISK"

step "Bootstrap complete. Boot with: ./launch-vm.sh"
