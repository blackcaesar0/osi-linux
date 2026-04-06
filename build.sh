#!/bin/bash
# ──────────────────────────────────────────────────────────────────────────────
# OSI Linux — Build a custom Kali-based live ISO using live-build
# ──────────────────────────────────────────────────────────────────────────────
# Usage: sudo ./build.sh [options]
#   --variant osi          (default, the only variant for now)
#   --distribution kali-rolling
#   --arch amd64
#   --output <path>        output ISO location
#   --verbose              show all build output
#   --clean                clean previous build first
#
# Prerequisites (Debian/Ubuntu/Kali host):
#   sudo apt install git live-build cdebootstrap devscripts
#
# The result is a hybrid ISO: bootable from USB (dd) or optical media.
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────
VARIANT="osi"
DISTRIBUTION="kali-rolling"
ARCH="amd64"
VERBOSE=""
DO_CLEAN=""
OUTPUT_ISO=""

# ── Parse arguments ───────────────────────────────────────────────────────────
while [ $# -gt 0 ]; do
    case "$1" in
        --variant)      VARIANT="$2";       shift 2 ;;
        --distribution) DISTRIBUTION="$2";  shift 2 ;;
        --arch)         ARCH="$2";          shift 2 ;;
        --output)       OUTPUT_ISO="$2";    shift 2 ;;
        --verbose)      VERBOSE="--verbose"; shift ;;
        --clean)        DO_CLEAN=1;         shift ;;
        *)              echo "Unknown option: $1"; exit 1 ;;
    esac
done

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/build"

step() { echo; echo "==> $*"; }

# ── Preflight checks ─────────────────────────────────────────────────────────
if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: Must run as root. Usage: sudo ./build.sh"
    exit 1
fi

MISSING=()
for cmd in lb debootstrap curl; do
    command -v "$cmd" &>/dev/null || MISSING+=("$cmd")
done
if [ "${#MISSING[@]}" -gt 0 ]; then
    echo "ERROR: Missing required tools: ${MISSING[*]}"
    echo ""
    echo "Install prerequisites:"
    echo "  Debian/Ubuntu/Kali: sudo apt install git live-build simple-cdd cdebootstrap devscripts"
    echo ""
    echo "If not on Kali, you also need the Kali archive keyring:"
    echo "  curl -fsSL https://archive.kali.org/archive-key.asc | sudo gpg --dearmor -o /usr/share/keyrings/kali-archive-keyring.gpg"
    exit 1
fi

# ── Kali archive keyring ─────────────────────────────────────────────────────
KALI_KEYRING="/usr/share/keyrings/kali-archive-keyring.gpg"
if [ ! -f "$KALI_KEYRING" ]; then
    step "Installing Kali archive keyring"
    # Try the package first, fall back to direct download
    if apt-get install -y kali-archive-keyring 2>/dev/null; then
        echo "    Installed from package."
    else
        curl -fsSL https://archive.kali.org/archive-key.asc \
            | gpg --dearmor -o "$KALI_KEYRING"
        echo "    Downloaded and installed."
    fi
fi

# ── Prepare build directory ───────────────────────────────────────────────────
step "Preparing build directory"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

if [ -n "$DO_CLEAN" ]; then
    step "Cleaning previous build"
    lb clean --purge 2>/dev/null || true
    rm -rf config/ .build/ cache/
fi

# ── Assemble includes.chroot from config/ ─────────────────────────────────────
# Copy desktop configs into the skel overlay so every new user gets them
step "Assembling rootfs overlay from config/"
INCLUDES="$PROJECT_DIR/kali-config/common/includes.chroot"
SKEL="$INCLUDES/etc/skel"

# Create skel directory structure
mkdir -p "$SKEL/.config/xfce4/terminal" \
         "$SKEL/.config/xfce4/xfconf/xfce-perchannel-xml" \
         "$SKEL/.config/gtk-3.0" \
         "$SKEL/.config/gtk-4.0" \
         "$SKEL/wallpaper"

# XFCE configs
cp "$PROJECT_DIR/config/xfce4/terminal/terminalrc" "$SKEL/.config/xfce4/terminal/"
cp "$PROJECT_DIR/config/xfce4/xfconf/xfce-perchannel-xml/"*.xml \
    "$SKEL/.config/xfce4/xfconf/xfce-perchannel-xml/"

# Shell, editor, multiplexer
cp "$PROJECT_DIR/config/shell/bash_aliases"        "$SKEL/.bash_aliases"
cp "$PROJECT_DIR/config/vim/vimrc"                 "$SKEL/.vimrc"
cp "$PROJECT_DIR/config/tmux/tmux.conf"            "$SKEL/.tmux.conf"

# Wallpaper — into skel and system-wide backgrounds
cp "$PROJECT_DIR/wallpaper/osi.png"                "$SKEL/wallpaper/"
mkdir -p "$INCLUDES/usr/share/backgrounds/osi"
cp "$PROJECT_DIR/wallpaper/osi.png"                "$INCLUDES/usr/share/backgrounds/osi/"

# genisoimage rejects files >4GB without -allow-limited-size.
# Must be exported BEFORE lb config so lb_config writes it into config/common.
# lb_binary_iso sources config/common via Read_conffiles, which would otherwise
# override any value we export after lb config has already run.
export GENISOIMAGE_OPTIONS_EXTRA="-allow-limited-size"

# ── lb config ─────────────────────────────────────────────────────────────────
step "Configuring live-build"
# lb wrapper (#!/bin/sh, set -e) builds ENV by running grep on each environment
# file. If config/environment.binary exists but is empty, grep -v '^#' returns
# exit 1 (no matches), which triggers set -e in POSIX sh and kills lb silently
# before lb_config ever runs. Delete the file — lb will recreate it if needed.
rm -f "$BUILD_DIR/config/environment.binary"

# Detect which flags the installed live-build supports.
# Newer versions dropped --debootstrap-options, --image-name, and --updates.
LB_EXTRA_ARGS=()
if lb config --help 2>&1 | grep -q -- '--debootstrap-options'; then
    # sysvinit-utils provides start-stop-daemon — required early by dpkg postinst scripts.
    # Without it, lb_chroot_install-packages fails with "start-stop-daemon not found in PATH".
    LB_EXTRA_ARGS+=( --debootstrap-options "--keyring=$KALI_KEYRING --include=sysvinit-utils" )
fi
if lb config --help 2>&1 | grep -q -- '--image-name'; then
    LB_EXTRA_ARGS+=( --image-name "osi-linux" )
fi
if lb config --help 2>&1 | grep -q -- '--updates'; then
    LB_EXTRA_ARGS+=( --updates false )
fi
if lb config --help 2>&1 | grep -q -- '--firmware-binary'; then
    LB_EXTRA_ARGS+=( --firmware-binary true --firmware-chroot true )
fi
if lb config --help 2>&1 | grep -q -- '--initsystem'; then
    LB_EXTRA_ARGS+=( --initsystem systemd )
fi

# Pass keyring to debootstrap via environment if the flag isn't available
export DEBOOTSTRAP_KEYRING="$KALI_KEYRING"

# Kali uses a single rolling repo — no separate security or updates repos.
# Setting --security false prevents live-build from appending /updates which 404s.
lb config \
    --distribution "$DISTRIBUTION" \
    --archive-areas "main contrib non-free non-free-firmware" \
    --mirror-bootstrap "http://http.kali.org/kali" \
    --mirror-chroot "http://http.kali.org/kali" \
    --mirror-binary "http://http.kali.org/kali" \
    --keyring-packages kali-archive-keyring \
    --architectures "$ARCH" \
    --linux-flavours "$ARCH" \
    --bootappend-live "boot=live components username=osi hostname=osi" \
    --apt-options "--yes --option Acquire::Retries=5" \
    --binary-images iso-hybrid \
    --iso-application "OSI Linux" \
    --iso-publisher "Offensive Security Initiative" \
    --iso-volume "OSI_LIVE" \
    --memtest none \
    --security false \
    --system live \
    "${LB_EXTRA_ARGS[@]}" \
    $VERBOSE

# ── Patch out updates repo — Kali has no kali-rolling-updates ────────────────
# lb_chroot_archives checks LB_VOLATILE (not LB_UPDATES) to decide whether to
# add $DISTRIBUTION-updates entries. Set both to false.
step "Patching out non-existent updates repo"
for cfg in "$BUILD_DIR/config/common" "$BUILD_DIR/config/bootstrap" "$BUILD_DIR/config/chroot" "$BUILD_DIR/config/binary"; do
    if [ -f "$cfg" ]; then
        for var in LB_UPDATES LB_VOLATILE; do
            if grep -q "^${var}=" "$cfg" 2>/dev/null; then
                sed -i "s/^${var}=.*/${var}=\"false\"/" "$cfg"
            else
                echo "${var}=\"false\"" >> "$cfg"
            fi
        done
        echo "    Patched $cfg"
    fi
done
# Also scan for any other config files that might have them
find "$BUILD_DIR/config" -type f 2>/dev/null | xargs -r grep -l 'LB_UPDATES\|LB_VOLATILE' 2>/dev/null \
    | xargs -r sed -i 's/LB_UPDATES="true"/LB_UPDATES="false"/g; s/LB_VOLATILE="true"/LB_VOLATILE="false"/g' 2>/dev/null || true
# Remove any pre-seeded sources.list files that reference -updates
find "$BUILD_DIR/config" -type f 2>/dev/null \
    | xargs -r sed -i '/-updates/d' 2>/dev/null || true

# Belt-and-suspenders: tell apt inside the chroot to treat missing repos as
# warnings instead of fatal errors. live-build copies config/apt/apt.conf.d/*
# into the chroot (lb_chroot_apt, step 11) BEFORE lb_chroot_archives (step 12)
# runs apt-get update, so this is in place when the 404 would otherwise fail.
step "Adding APT notes for Kali rolling (bad -updates lines stripped by apt-get wrapper)"
mkdir -p "$BUILD_DIR/config/apt/apt.conf.d"
cat > "$BUILD_DIR/config/apt/apt.conf.d/99ignore-missing-repos" << 'APTEOF'
// Kali rolling has no separate -updates / -security suites. Non-existent lines are
// removed before "apt-get update" by the build-time wrapper in build.sh.
// Do not set APT::Update::Error-Mode "any" here — that mode aborts update on any error.
Acquire::AllowInsecureRepositories "false";
APTEOF
echo "    Created config/apt/apt.conf.d/99ignore-missing-repos"

# ── Copy our variant package list ─────────────────────────────────────────────
step "Installing package lists and overlays"
VARIANT_DIR="$PROJECT_DIR/kali-config/variant-$VARIANT"
if [ ! -d "$VARIANT_DIR" ]; then
    echo "ERROR: Variant '$VARIANT' not found at $VARIANT_DIR"
    exit 1
fi

# Package list
cp "$VARIANT_DIR/package-lists/"*.list.chroot "$BUILD_DIR/config/package-lists/" 2>/dev/null || true

# Hooks
cp "$PROJECT_DIR/kali-config/common/hooks/live/"*.hook.chroot "$BUILD_DIR/config/hooks/live/" 2>/dev/null || true

# Squashfs excludes (omit build-only files from the live filesystem image)
mkdir -p "$BUILD_DIR/config/binary_rootfs"
if [ -f "$PROJECT_DIR/kali-config/common/binary_rootfs/excludes" ]; then
    cp "$PROJECT_DIR/kali-config/common/binary_rootfs/excludes" "$BUILD_DIR/config/binary_rootfs/excludes"
    echo "    Installed config/binary_rootfs/excludes"
fi

# Rootfs overlay (configs, skel, sysctl, etc.)
cp -a "$PROJECT_DIR/kali-config/common/includes.chroot/"* "$BUILD_DIR/config/includes.chroot/" 2>/dev/null || true

# ── Build (staged) ────────────────────────────────────────────────────────────
# live-build's lb_chroot_archives generates a sources.list entry for
# kali-rolling-updates (which 404s).  Fix: run bootstrap first, then replace
# apt-get in the chroot with a thin wrapper that strips the -updates line
# from sources.list before every "update" call.  This is deterministic —
# no race conditions, no config files for live-build to overwrite.

if [ ! -e "$BUILD_DIR/.build/bootstrap" ]; then
    step "Stage 1/3: Bootstrap"
    lb bootstrap 2>&1 | tee -a "$BUILD_DIR/build.log"
else
    step "Stage 1/3: Bootstrap (cached — skipping)"
fi

step "Installing apt-get wrapper to strip non-existent repos"
APT_REAL="$BUILD_DIR/chroot/usr/bin/apt-get.real"
APT_WRAPPER="$BUILD_DIR/chroot/usr/bin/apt-get"
cp "$APT_WRAPPER" "$APT_REAL"
cat > "$APT_WRAPPER" << 'WRAPEOF'
#!/bin/bash
# OSI Linux build wrapper — strips non-existent kali-rolling-updates from
# sources.list before apt-get update.
# If the chroot stage is already complete (.build/chroot exists), skip the
# update entirely: the binary stage only needs packages that are pre-installed,
# and re-running apt-get update hangs on slow CDN mirrors.
for arg in "$@"; do
    if [ "$arg" = "update" ]; then
        sed -i '/-updates/d; /-security/d' /etc/apt/sources.list 2>/dev/null || true
        if [ -e /build_chroot_done ]; then
            exit 0
        fi
        break
    fi
done
exec /usr/bin/apt-get.real "$@"
WRAPEOF
chmod +x "$APT_WRAPPER"
echo "    Installed wrapper: apt-get → apt-get.real"

step "Stage 2/3: Chroot (installing packages — this is the slow part)"
# Check if chroot is already complete before running

# Ensure dpkg inside the chroot can find start-stop-daemon and other sbin tools.
# On merged-usr hosts the chroot may not have /sbin in PATH — dpkg requires it.
cat > "$BUILD_DIR/config/environment.chroot" << 'ENVEOF'
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENVEOF

# Belt-and-suspenders: also create the symlink directly in the chroot if missing.
if [ ! -e "$BUILD_DIR/chroot/sbin" ]; then
    ln -sf usr/sbin "$BUILD_DIR/chroot/sbin" 2>/dev/null || true
fi
if [ ! -e "$BUILD_DIR/chroot/usr/sbin/start-stop-daemon" ] && \
   [ -e "$BUILD_DIR/chroot/sbin/start-stop-daemon" ]; then
    mkdir -p "$BUILD_DIR/chroot/usr/sbin"
    cp "$BUILD_DIR/chroot/sbin/start-stop-daemon" "$BUILD_DIR/chroot/usr/sbin/" 2>/dev/null || true
fi

if [ ! -e "$BUILD_DIR/.build/chroot" ]; then
    lb chroot 2>&1 | tee -a "$BUILD_DIR/build.log"
else
    echo "    Chroot already built — skipping lb chroot"
fi

# Sentinel read by the apt-get wrapper inside the chroot: once this file exists,
# apt-get update calls return 0 immediately (no network hang during lb_binary).
touch "$BUILD_DIR/chroot/build_chroot_done"

step "Pre-installing binary-stage dependencies"
# lb_binary_syslinux and lb_binary_iso run apt-get inside the chroot to install
# genisoimage, syslinux, librsvg2-bin, and mtools. Before lb binary runs it also
# calls lb chroot_archives chroot install which runs apt-get update — this can
# hang for minutes on slow Kali CDN mirrors.
# Pre-install everything lb binary needs now (using the existing chroot apt cache)
# and set a short APT http timeout so any remaining update calls fail fast instead
# of hanging indefinitely.
mkdir -p "$BUILD_DIR/chroot/etc/apt/apt.conf.d"
cat > "$BUILD_DIR/chroot/etc/apt/apt.conf.d/99-osi-timeout" << 'APTEOF'
Acquire::http::Timeout "30";
Acquire::https::Timeout "30";
Acquire::Retries "1";
APTEOF
chroot "$BUILD_DIR/chroot" apt-get install -y \
    genisoimage syslinux syslinux-common mtools librsvg2-bin 2>&1 \
    | tee -a "$BUILD_DIR/build.log" || true

step "Stage 3/3: Binary (assembling ISO)"

# Suppress needrestart and debconf interactive prompts inside the binary chroot.
# Exporting env vars is not enough — lb_binary_syslinux runs apt-get inside the
# chroot via chroot(1) which doesn't inherit the host environment. Write a
# needrestart drop-in that permanently disables the kernel-mismatch prompt and
# sets automatic restart mode for the duration of the build. The same file is
# copied into the inner rootfs by lb binary_chroot; config/binary_rootfs/excludes
# keeps it out of filesystem.squashfs so the live image is not affected.
mkdir -p "$BUILD_DIR/chroot/etc/needrestart/conf.d"
cat > "$BUILD_DIR/chroot/etc/needrestart/conf.d/99-osi-build.conf" << 'NREOF'
$nrconf{restart}     = 'a';
$nrconf{kernelhints} = 0;
$nrconf{ucodehints}  = 0;
$nrconf{ui}          = 'n';
NREOF
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export NEEDRESTART_SUSPEND=1

# Fix syslinux bootloader files in lb's bootloaders directory.
# lb's bootloaders/isolinux/ ships broken symlinks and is missing modules required
# by syslinux 6.x. Files moved paths between distros (Debian vs Ubuntu vs Kali):
#   isolinux.bin  → /usr/lib/ISOLINUX/        (not /usr/lib/syslinux/)
#   *.c32 modules → /usr/lib/syslinux/modules/bios/  (not /usr/lib/syslinux/)
# isolinux.bin loads ldlinux.c32 first; without it boot fails with "Failed to
# load ldlinux.c32". vesamenu.c32 further requires libcom32, libutil, libmenu.
_LB_ISOLINUX_DIR="/usr/share/live/build/bootloaders/isolinux"

_syslinux_copy() {
    local name="$1" src="$2"
    if [ -e "$src" ]; then
        # Remove broken symlink or stale copy, then replace
        rm -f "$_LB_ISOLINUX_DIR/$name"
        cp "$src" "$_LB_ISOLINUX_DIR/$name"
        echo "    Installed $name from $src"
    else
        echo "    WARNING: $src not found — $name may be missing from ISO"
    fi
}

# isolinux.bin — path moved in modern syslinux packages
if [ -L "$_LB_ISOLINUX_DIR/isolinux.bin" ] || [ ! -s "$_LB_ISOLINUX_DIR/isolinux.bin" ]; then
    _syslinux_copy isolinux.bin /usr/lib/ISOLINUX/isolinux.bin
fi

# Core c32 modules required by syslinux 6.x — copy if missing or broken symlink
_C32_SRC="/usr/lib/syslinux/modules/bios"
for _mod in ldlinux.c32 libcom32.c32 libutil.c32 libmenu.c32 vesamenu.c32; do
    if [ -L "$_LB_ISOLINUX_DIR/$_mod" ] || [ ! -s "$_LB_ISOLINUX_DIR/$_mod" ]; then
        _syslinux_copy "$_mod" "$_C32_SRC/$_mod"
    fi
done
# Remove any stale isolinux staging dir from previous runs. cp -a over a directory
# containing broken symlinks doesn't replace them — it tries to follow them and fails.
# A fresh copy is the only reliable option.
rm -rf "$BUILD_DIR/chroot/root/isolinux"
# Also remove binary/isolinux so lb's mv step renames rather than nests.
rm -rf "$BUILD_DIR/binary/isolinux"

# lb_binary_syslinux renames vmlinuz-<ver> → vmlinuz on first run. On retries the
# versioned name is gone and the glob fails. Restore versioned names if needed.
# Guard with || true: no vmlinuz in chroot on a clean binary run is normal.
_KVER=$(ls "$BUILD_DIR/chroot/boot/vmlinuz-"* 2>/dev/null | sed 's/.*vmlinuz-//' | head -1 || true)
if [ -n "$_KVER" ]; then
    if [ -f "$BUILD_DIR/binary/live/vmlinuz" ] && \
       [ ! -f "$BUILD_DIR/binary/live/vmlinuz-${_KVER}" ]; then
        mv "$BUILD_DIR/binary/live/vmlinuz" "$BUILD_DIR/binary/live/vmlinuz-${_KVER}"
        echo "    Restored vmlinuz → vmlinuz-${_KVER}"
    fi
    if [ -f "$BUILD_DIR/binary/live/initrd.img" ] && \
       [ ! -f "$BUILD_DIR/binary/live/initrd.img-${_KVER}" ]; then
        mv "$BUILD_DIR/binary/live/initrd.img" "$BUILD_DIR/binary/live/initrd.img-${_KVER}"
        echo "    Restored initrd.img → initrd.img-${_KVER}"
    fi
fi

# lb_binary_syslinux unconditionally tries to unpack binary/isolinux/bootlogo
# (Ubuntu gfxboot code that runs for all modes). It doesn't exist for Kali/Debian
# builds. Add an empty valid cpio archive to the lb bootloaders source dir so it
# gets carried through cp-a → cp-aL → mv into binary/isolinux/ automatically.
(cd /tmp && cpio --quiet -o < /dev/null) > "$_LB_ISOLINUX_DIR/bootlogo"

# librsvg2-bin renamed rsvg → rsvg-convert and changed argument syntax.
# Old: rsvg [opts] input.svg output.png
# New: rsvg-convert [opts] -o output.png input.svg
# A symlink isn't enough — write a wrapper that translates the call.
# Write unconditionally: lb_binary_syslinux installs librsvg2-bin (rsvg-convert)
# inside a copy of the chroot AFTER our pre-flight runs, so checking for
# rsvg-convert here would always be false. The wrapper must exist before the copy.
cat > "$BUILD_DIR/chroot/usr/bin/rsvg" << 'RSVGEOF'
#!/bin/bash
# Old live-build calls: rsvg [opts] <input.svg> <output.png>
# rsvg-convert wants: rsvg-convert [opts] -o <output> <input>
args=("$@")
n=${#args[@]}
if [ "$n" -lt 2 ]; then
	exec rsvg-convert "$@"
fi
output="${args[$((n-1))]}"
input="${args[$((n-2))]}"
opts=("${args[@]:0:$((n-2))}")
exec rsvg-convert "${opts[@]}" -o "$output" "$input"
RSVGEOF
chmod +x "$BUILD_DIR/chroot/usr/bin/rsvg"
echo "    Created rsvg compat wrapper in chroot"

# Verify config/common has GENISOIMAGE_OPTIONS_EXTRA set. lb_binary_iso sources
# config/common via Read_conffiles which would override any exported value — so
# the config file is the authoritative place. Belt-and-suspenders patch it here
# in case a rebuild reused a stale config/ from before the export was moved.
if grep -q 'GENISOIMAGE_OPTIONS_EXTRA=""' "$BUILD_DIR/config/common" 2>/dev/null; then
    sed -i 's|GENISOIMAGE_OPTIONS_EXTRA=""|GENISOIMAGE_OPTIONS_EXTRA="-allow-limited-size"|' \
        "$BUILD_DIR/config/common"
    echo "    Patched GENISOIMAGE_OPTIONS_EXTRA in config/common"
fi

# isohybrid makes the ISO bootable from USB (hybrid ISO). lb's Check_package looks
# for it in the chroot. A symlink to /usr/bin/isohybrid resolves *inside* the
# chroot and is broken there — copy the host binary instead.
if [ -x /usr/bin/isohybrid ] && [ ! -x "$BUILD_DIR/chroot/usr/bin/isohybrid" ]; then
    cp -f /usr/bin/isohybrid "$BUILD_DIR/chroot/usr/bin/isohybrid"
    chmod +x "$BUILD_DIR/chroot/usr/bin/isohybrid"
    echo "    Copied isohybrid into chroot"
fi

lb binary 2>&1 | tee -a "$BUILD_DIR/build.log"

step "Restoring real apt-get in chroot"
if [ -f "$APT_REAL" ]; then
    mv "$APT_REAL" "$APT_WRAPPER"
    echo "    Restored original apt-get"
fi
rm -f "$BUILD_DIR/chroot/build_chroot_done"

# ── Output ────────────────────────────────────────────────────────────────────
# Find the built ISO — name depends on live-build version and --image-name support
ISO_FILE=$(ls "$BUILD_DIR"/osi-linux-*.iso 2>/dev/null | head -1)
[ -z "$ISO_FILE" ] && ISO_FILE=$(ls "$BUILD_DIR"/live-image-*.iso 2>/dev/null | head -1)
[ -z "$ISO_FILE" ] && ISO_FILE=$(ls "$BUILD_DIR"/*.iso 2>/dev/null | head -1)
if [ -z "$ISO_FILE" ]; then
    echo "ERROR: Build failed — no ISO found. Check build.log"
    exit 1
fi

if [ -n "$OUTPUT_ISO" ]; then
    mkdir -p "$(dirname "$OUTPUT_ISO")"
    mv "$ISO_FILE" "$OUTPUT_ISO"
    ISO_FILE="$OUTPUT_ISO"
fi

# Fix ownership for the invoking user
REAL_USER="${SUDO_USER:-$USER}"
chown "$REAL_USER:$REAL_USER" "$ISO_FILE"

echo ""
echo "============================================"
echo "  OSI Linux ISO built successfully!"
echo "============================================"
echo ""
echo "  ISO:    $ISO_FILE"
echo "  Size:   $(du -sh "$ISO_FILE" | cut -f1)"
echo "  SHA256: $(sha256sum "$ISO_FILE" | cut -d' ' -f1)"
echo ""
echo "  Test in QEMU:"
echo "    qemu-system-x86_64 -cdrom $ISO_FILE -m 4G -enable-kvm -boot d"
echo ""
echo "  Write to USB:"
echo "    sudo dd if=$ISO_FILE of=/dev/sdX bs=4M status=progress oflag=sync"
echo ""
echo "  Create a VM disk:"
echo "    bash scripts/create-vm.sh $ISO_FILE"
