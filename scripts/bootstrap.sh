#!/bin/bash
# Run as root on the HOST to bootstrap Void Linux into the qcow2 disk.
# This replaces the live ISO installer entirely.
set -e

DISK="$HOME/VM/osi-linux.qcow2"
MNT="/mnt/voidroot"
NBD="/dev/nbd0"
REPO="https://repo-default.voidlinux.org/current"
XBPS_STATIC="$HOME/VM/bootstrap/usr/bin/xbps-install.static"

step() { echo; echo "==> $*"; }

# ── Step 1: static xbps ───────────────────────────────────────────────────────
step "Downloading static xbps binary"
mkdir -p "$HOME/VM/bootstrap"
if [ ! -f "$XBPS_STATIC" ]; then
    curl -fsSL https://repo-default.voidlinux.org/static/xbps-static-latest.x86_64-musl.tar.xz \
        | tar xJ -C "$HOME/VM/bootstrap"
fi
echo "OK: $XBPS_STATIC"

# ── Step 2: create disk ───────────────────────────────────────────────────────
step "Creating qcow2 disk"
if [ -f "$DISK" ]; then
    echo "Disk already exists, skipping creation."
else
    mkdir -p "$HOME/VM"
    qemu-img create -f qcow2 "$DISK" 80G
fi

# ── Step 3: NBD ───────────────────────────────────────────────────────────────
step "Connecting disk via NBD"
modprobe nbd max_part=8
qemu-nbd --connect="$NBD" "$DISK"
sleep 1
lsblk "$NBD"

# ── Step 4: partition ─────────────────────────────────────────────────────────
step "Partitioning disk (GPT: 512M EFI + rest root)"
sgdisk -Z "$NBD"
sgdisk -n 1:0:+512M -t 1:ef00 -c 1:"EFI"  "$NBD"
sgdisk -n 2:0:0     -t 2:8300 -c 2:"root" "$NBD"
partprobe "$NBD"
sleep 1

# ── Step 5: format ────────────────────────────────────────────────────────────
step "Formatting partitions"
mkfs.fat -F32 -n EFI    "${NBD}p1"
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
set -e

chown root:root /
chmod 755 /

ln -sf /usr/share/zoneinfo/UTC /etc/localtime
echo "osi-linux" > /etc/hostname

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

useradd -m -G wheel,audio,video,usb,cdrom,input,network -s /bin/bash osi

xbps-install -y grub-x86_64-efi efibootmgr
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=OSI --recheck
grub-mkconfig -o /boot/grub/grub.cfg

echo "----"
echo "Set root password:"
passwd root
echo "Set password for user 'osi':"
passwd osi
CHROOT

# ── Step 10: unmount ──────────────────────────────────────────────────────────
step "Unmounting and disconnecting"
umount -R "$MNT"
qemu-nbd --disconnect "$NBD"
rmmod nbd 2>/dev/null || true

step "Bootstrap complete. Boot the VM with: ./launch-vm.sh"
