#!/bin/bash
# Run as root on the HOST to bootstrap Void Linux into the qcow2 disk.
# Usage: sudo bash scripts/bootstrap.sh
set -euo pipefail

# Resolve the invoking user's home directory even under sudo
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

# ── CONFIGURATION — override via environment variables ────────────────────────
DISK_SIZE="${DISK_SIZE:-80G}"
VM_HOSTNAME="${VM_HOSTNAME:-osi-linux}"
VM_USER="${VM_USER:-osi}"

DISK="${DISK_IMAGE:-$REAL_HOME/VM/osi-linux.qcow2}"
MNT="/mnt/voidroot"
NBD="/dev/nbd0"
REPO="https://repo-default.voidlinux.org/current"
XBPS_DIR="$REAL_HOME/VM/bootstrap"
XBPS_STATIC="$XBPS_DIR/usr/bin/xbps-install.static"

step() { echo; echo "==> $*"; }

cleanup() {
    echo "==> Cleaning up..."
    umount -R "$MNT" 2>/dev/null || true
    qemu-nbd --disconnect "$NBD" 2>/dev/null || true
    rmmod nbd 2>/dev/null || true
}
trap cleanup EXIT

# ── Preflight checks ──────────────────────────────────────────────────────────
for cmd in qemu-img qemu-nbd sgdisk mkfs.fat mkfs.ext4 curl blkid udevadm; do
    command -v "$cmd" &>/dev/null || { echo "ERROR: $cmd not found. Install it first."; exit 1; }
done

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: Run as root: sudo bash scripts/bootstrap.sh"
    exit 1
fi

# ── Passwords up front (interactive, before any automation) ───────────────────
step "Set passwords before we begin"
echo -n "Root password: "; read -rs ROOT_PASS; echo
echo -n "Confirm root password: "; read -rs ROOT_PASS2; echo
[ "$ROOT_PASS" = "$ROOT_PASS2" ] || { echo "Passwords do not match."; exit 1; }

echo -n "Password for user '$VM_USER': "; read -rs OSI_PASS; echo
echo -n "Confirm $VM_USER password: "; read -rs OSI_PASS2; echo
[ "$OSI_PASS" = "$OSI_PASS2" ] || { echo "Passwords do not match."; exit 1; }

# ── Step 1: static xbps ───────────────────────────────────────────────────────
step "Downloading static xbps binary"
mkdir -p "$XBPS_DIR"
if [ ! -f "$XBPS_STATIC" ]; then
    curl -fsSL https://repo-default.voidlinux.org/static/xbps-static-latest.x86_64-musl.tar.xz \
        | tar xJ -C "$XBPS_DIR"
fi
echo "OK: $XBPS_STATIC"

# ── Step 2: create disk ───────────────────────────────────────────────────────
step "Creating qcow2 disk"
mkdir -p "$REAL_HOME/VM"
if [ ! -f "$DISK" ]; then
    qemu-img create -f qcow2 "$DISK" "$DISK_SIZE"
    chown "$REAL_USER:$REAL_USER" "$DISK"
else
    echo "Disk already exists, skipping."
fi

# ── Step 3: NBD ───────────────────────────────────────────────────────────────
step "Connecting disk via NBD"
modprobe nbd max_part=8
qemu-nbd --connect="$NBD" "$DISK"
udevadm settle
lsblk "$NBD"

# ── Step 4: partition ─────────────────────────────────────────────────────────
step "Partitioning disk (GPT: 512M EFI + rest root)"
sgdisk -Z "$NBD"
sgdisk -n 1:0:+512M -t 1:ef00 -c 1:"EFI"  "$NBD"
sgdisk -n 2:0:0     -t 2:8300 -c 2:"root" "$NBD"
partprobe "$NBD"
udevadm settle

# ── Step 5: format ────────────────────────────────────────────────────────────
step "Formatting partitions"
mkfs.fat -F32 -n EFI     "${NBD}p1"
mkfs.ext4 -L voidroot -F "${NBD}p2"

# ── Step 6: mount ─────────────────────────────────────────────────────────────
step "Mounting"
mkdir -p "$MNT"
mount "${NBD}p2" "$MNT"
mkdir -p "$MNT/boot/efi"
mount "${NBD}p1" "$MNT/boot/efi"

# ── Step 7: bootstrap ─────────────────────────────────────────────────────────
step "Bootstrapping Void Linux base system (this will take a few minutes)"
XBPS_ARCH=x86_64 "$XBPS_STATIC" -S -r "$MNT" -R "$REPO" base-system

# ── Step 8: bind mounts ───────────────────────────────────────────────────────
step "Binding host filesystems for chroot"
mount --rbind /sys  "$MNT/sys"  && mount --make-rslave "$MNT/sys"
mount --rbind /dev  "$MNT/dev"  && mount --make-rslave "$MNT/dev"
mount --rbind /proc "$MNT/proc" && mount --make-rslave "$MNT/proc"
cp /etc/resolv.conf "$MNT/etc/"

# ── Step 9: configure inside chroot ──────────────────────────────────────────
step "Configuring system inside chroot"

UUID_ROOT=$(blkid -s UUID -o value "${NBD}p2")
UUID_EFI=$(blkid  -s UUID -o value "${NBD}p1")

chroot "$MNT" /bin/bash << CHROOT
set -euo pipefail

chown root:root /
chmod 755 /

ln -sf /usr/share/zoneinfo/UTC /etc/localtime
echo "$VM_HOSTNAME" > /etc/hostname

echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "en_US.UTF-8 UTF-8" >> /etc/default/libc-locales
xbps-reconfigure -f glibc-locales

cat > /etc/rc.conf << 'RC'
TIMEZONE="UTC"
KEYMAP="us"
HARDWARECLOCK="UTC"
RC

cat > /etc/fstab << FSTAB
UUID=$UUID_ROOT /         ext4  defaults             0 1
UUID=$UUID_EFI  /boot/efi vfat  defaults             0 2
tmpfs           /tmp      tmpfs defaults,nosuid,nodev 0 0
FSTAB

xbps-install -y sudo
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel

useradd -m -G wheel,audio,video,usb,cdrom,input,network -s /bin/bash "$VM_USER"

echo "root:$ROOT_PASS"      | chpasswd
echo "$VM_USER:$OSI_PASS"   | chpasswd

xbps-install -y grub-x86_64-efi efibootmgr
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=OSI --recheck
grub-mkconfig -o /boot/grub/grub.cfg
CHROOT

# cleanup trap handles unmount/disconnect
step "Bootstrap complete. Boot with: ./launch-vm.sh"
