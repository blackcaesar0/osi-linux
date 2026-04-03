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
echo "osi ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/99-osi-nopasswd
chmod 0440 /etc/sudoers.d/99-osi-nopasswd
LIVEUSER

# Set passwords outside the chroot heredoc using openssl — chpasswd can fail
# silently if PAM/libcrypt isn't fully configured in the chroot
OSI_HASH=$(openssl passwd -6 "osi")
ROOT_HASH=$(openssl passwd -6 "root")
[ -n "$OSI_HASH" ]  || { echo "ERROR: openssl failed to generate osi password hash"; exit 1; }
[ -n "$ROOT_HASH" ] || { echo "ERROR: openssl failed to generate root password hash"; exit 1; }
chroot "$ROOTFS" usermod -p "$OSI_HASH" osi   || { echo "ERROR: failed to set osi password"; exit 1; }
chroot "$ROOTFS" usermod -p "$ROOT_HASH" root  || { echo "ERROR: failed to set root password"; exit 1; }
echo "    Live user: osi/osi  Root: root/root"

# ── Copy project into rootfs ─────────────────────────────────────────────────
step "Copying osi-setup scripts into live image"
SETUP_DEST="$ROOTFS/home/osi/osi-setup"
rm -rf "$SETUP_DEST"
cp -r "$PROJECT_DIR" "$SETUP_DEST"
rm -rf "$SETUP_DEST/VM"
chroot "$ROOTFS" chown -R osi:osi /home/osi/osi-setup
echo "    Scripts available at ~/osi-setup inside the live image"

# ── Deploy configs directly (chroot-safe) ────────────────────────────────────
# Cannot run deploy-configs.sh as-is because sysctl and git clones fail in
# chroot.  Instead, deploy configs and services directly.
step "Deploying desktop configs for osi user"
OSI_HOME="$ROOTFS/home/osi"

# Config directories
mkdir -p "$OSI_HOME/.config/awesome" \
         "$OSI_HOME/.config/alacritty" \
         "$OSI_HOME/.config/rofi" \
         "$OSI_HOME/.config/picom" \
         "$OSI_HOME/wallpaper" \
         "$OSI_HOME/.local/bin" \
         "$OSI_HOME/bin" \
         "$OSI_HOME/tools"/{recon,exploitation,post-exploitation,web,network,forensics,custom,wordlists} \
         "$OSI_HOME/go"/{bin,pkg,src}

# Awesome WM
cp "$PROJECT_DIR/config/awesome/rc.lua"           "$OSI_HOME/.config/awesome/"
cp "$PROJECT_DIR/config/awesome/theme.lua"        "$OSI_HOME/.config/awesome/"

# Application configs
cp "$PROJECT_DIR/config/alacritty/alacritty.toml" "$OSI_HOME/.config/alacritty/"
cp "$PROJECT_DIR/config/rofi/osi.rasi"            "$OSI_HOME/.config/rofi/"
cp "$PROJECT_DIR/config/picom/picom.conf"         "$OSI_HOME/.config/picom/"
cp "$PROJECT_DIR/wallpaper/osi.png"               "$OSI_HOME/wallpaper/"

# Shell configs
cp "$PROJECT_DIR/config/shell/bash_aliases"       "$OSI_HOME/.bash_aliases"
cp "$PROJECT_DIR/config/vim/vimrc"                "$OSI_HOME/.vimrc"
cp "$PROJECT_DIR/config/tmux/tmux.conf"           "$OSI_HOME/.tmux.conf"

# .xinitrc — launch awesome via dbus
cat > "$OSI_HOME/.xinitrc" << 'EOF'
#!/bin/sh
export XDG_SESSION_TYPE=x11
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
mkdir -p "$XDG_RUNTIME_DIR"
exec dbus-launch --exit-with-session awesome
EOF
chmod +x "$OSI_HOME/.xinitrc"

# Runit services (spice-vdagent, qemu-ga)
cp -r "$PROJECT_DIR/config/runit/spice-vdagent" "$ROOTFS/etc/sv/" 2>/dev/null || true
cp -r "$PROJECT_DIR/config/runit/qemu-ga"       "$ROOTFS/etc/sv/" 2>/dev/null || true
chmod +x "$ROOTFS/etc/sv/spice-vdagent/run"     2>/dev/null || true
chmod +x "$ROOTFS/etc/sv/qemu-ga/run"           2>/dev/null || true
ln -sf /etc/sv/spice-vdagent "$ROOTFS/etc/runit/runsvdir/default/spice-vdagent" 2>/dev/null || true
ln -sf /etc/sv/qemu-ga       "$ROOTFS/etc/runit/runsvdir/default/qemu-ga"       2>/dev/null || true

# System config (sysctl, sudoers, limits, timezone) — skip sysctl -p in chroot
mkdir -p "$ROOTFS/etc/sysctl.d" "$ROOTFS/etc/security/limits.d"
cp "$PROJECT_DIR/scripts/sysconfig.sh" "$ROOTFS/tmp/"
# Write sysctl and limits configs directly — sysctl -p cannot run in chroot
cat > "$ROOTFS/etc/sysctl.d/99-osi.conf" << 'SYSCTL'
net.core.rmem_max        = 134217728
net.core.wmem_max        = 134217728
net.core.rmem_default    = 16777216
net.core.wmem_default    = 16777216
net.ipv4.tcp_rmem        = 4096 87380 134217728
net.ipv4.tcp_wmem        = 4096 65536 134217728
net.core.netdev_max_backlog = 5000
kernel.core_pattern      = /tmp/core.%e.%p
kernel.core_uses_pid     = 1
fs.suid_dumpable         = 2
fs.inotify.max_user_watches   = 524288
fs.inotify.max_user_instances = 512
kernel.perf_event_paranoid = 1
fs.file-max = 2097152
SYSCTL
cat > "$ROOTFS/etc/security/limits.d/99-osi.conf" << 'LIMITS'
*    soft nofile  65535
*    hard nofile  65535
osi  soft nofile  1048576
osi  hard nofile  1048576
LIMITS

# openntpd service
mkdir -p "$ROOTFS/etc/sv/openntpd"
cat > "$ROOTFS/etc/sv/openntpd/run" << 'EOF'
#!/bin/sh
exec /usr/sbin/ntpd -d -s -f /etc/ntpd.conf 2>&1
EOF
chmod +x "$ROOTFS/etc/sv/openntpd/run"
ln -sf /etc/sv/openntpd "$ROOTFS/etc/runit/runsvdir/default/openntpd" 2>/dev/null || true

# GTK + icon theme setup
chroot "$ROOTFS" su - osi -c "bash /home/osi/osi-setup/scripts/setup-icons.sh" || true

# Shell environment (bash_aliases, prompt, workspace stubs)
chroot "$ROOTFS" su - osi -c "bash /home/osi/osi-setup/scripts/shell-env.sh" || true

# Fix ownership on everything we touched
chroot "$ROOTFS" chown -R osi:osi /home/osi

# ── Configure emptty to auto-launch awesome for osi ──────────────────────────
step "Setting emptty to default to awesome WM for osi"
mkdir -p "$ROOTFS/etc/emptty"
cat > "$ROOTFS/etc/emptty/conf" << 'EOF'
TTY_NUMBER=7
SWITCH_TTY=true
PRINT_ISSUE=true
PRINT_MOTD=false
AUTOLOGIN=false
DBUS_LAUNCH=true
XINITRC_LAUNCH=true
VERTICAL_SELECTION=false
LOGGING=rotate
FG_COLOR=LIGHT_WHITE
BG_COLOR=BLACK
DEFAULT_USER=osi
EOF

# Per-user emptty config — auto-select awesome
mkdir -p "$OSI_HOME/.config/emptty"
cat > "$OSI_HOME/.config/emptty/env" << 'EOF'
DISPLAY_START_CMD=awesome
XINITRC=$HOME/.xinitrc
EOF
chroot "$ROOTFS" chown -R osi:osi /home/osi/.config/emptty

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
# dmsquash-live expects: squashfs.img → LiveOS/rootfs.img (ext4 loop image)
# We create an ext4 image, copy the rootfs into it, then wrap it in squashfs.
step "Creating ext4 rootfs image"
ROOTFS_SIZE=$(du -sm "$ROOTFS" --exclude="$ROOTFS/proc" --exclude="$ROOTFS/sys" \
    --exclude="$ROOTFS/dev" --exclude="$ROOTFS/tmp" | awk '{print $1}')
# Add 10% headroom
ROOTFS_SIZE=$(( ROOTFS_SIZE + ROOTFS_SIZE / 10 ))
echo "    Rootfs size: ${ROOTFS_SIZE}M (with headroom)"

ROOTFS_IMG="$WORK_DIR/rootfs.img"
truncate -s "${ROOTFS_SIZE}M" "$ROOTFS_IMG"
mkfs.ext4 -F -L "LiveOS-rootfs" "$ROOTFS_IMG"

ROOTFS_MNT="$WORK_DIR/rootfs-mnt"
mkdir -p "$ROOTFS_MNT"
mount -o loop "$ROOTFS_IMG" "$ROOTFS_MNT"

step "Copying rootfs into ext4 image (this takes a while)"
rsync -aHAX --info=progress2 \
    --exclude='/proc/*' --exclude='/sys/*' --exclude='/dev/*' --exclude='/tmp/*' \
    "$ROOTFS/" "$ROOTFS_MNT/"
umount "$ROOTFS_MNT"

step "Creating squashfs image (xz compression — this takes a while)"
SQUASH_SRC="$WORK_DIR/squash-src"
mkdir -p "$SQUASH_SRC/LiveOS" "$ISO_STAGE/LiveOS"
mv "$ROOTFS_IMG" "$SQUASH_SRC/LiveOS/rootfs.img"
mksquashfs "$SQUASH_SRC" "$ISO_STAGE/LiveOS/squashfs.img" \
    -comp xz -Xdict-size 100% -noappend
rm -rf "$SQUASH_SRC"

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
