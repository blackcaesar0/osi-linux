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

# ── lb config ─────────────────────────────────────────────────────────────────
step "Configuring live-build"

# Detect which flags the installed live-build supports.
# Newer versions dropped --debootstrap-options, --image-name, and --updates.
LB_EXTRA_ARGS=()
if lb config --help 2>&1 | grep -q -- '--debootstrap-options'; then
    LB_EXTRA_ARGS+=( --debootstrap-options "--keyring=$KALI_KEYRING" )
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
    --iso-publisher "OSI Team" \
    --iso-volume "OSI_LIVE" \
    --memtest none \
    --security false \
    "${LB_EXTRA_ARGS[@]}" \
    $VERBOSE

# ── Patch out updates repo — Kali has no kali-rolling-updates ────────────────
# live-build ignores --updates false on some versions and still generates
# a sources.list entry for $DISTRIBUTION-updates which 404s on Kali.
# Force LB_UPDATES=false in every config file lb generates.
step "Patching out non-existent updates repo"
for cfg in "$BUILD_DIR/config/common" "$BUILD_DIR/config/bootstrap" "$BUILD_DIR/config/chroot" "$BUILD_DIR/config/binary"; do
    if [ -f "$cfg" ]; then
        if grep -q '^LB_UPDATES=' "$cfg" 2>/dev/null; then
            sed -i 's/^LB_UPDATES=.*/LB_UPDATES="false"/' "$cfg"
        else
            echo 'LB_UPDATES="false"' >> "$cfg"
        fi
        echo "    Patched $cfg"
    fi
done
# Also scan for any other config files that might have it
find "$BUILD_DIR/config" -type f 2>/dev/null | xargs -r grep -l 'LB_UPDATES' 2>/dev/null \
    | xargs -r sed -i 's/LB_UPDATES="true"/LB_UPDATES="false"/g' 2>/dev/null || true
# Remove any pre-seeded sources.list files that reference -updates
find "$BUILD_DIR/config" -type f 2>/dev/null \
    | xargs -r sed -i '/-updates/d' 2>/dev/null || true

# Belt-and-suspenders: tell apt inside the chroot to treat missing repos as
# warnings instead of fatal errors. live-build copies config/apt/apt.conf.d/*
# into the chroot (lb_chroot_apt, step 11) BEFORE lb_chroot_archives (step 12)
# runs apt-get update, so this is in place when the 404 would otherwise fail.
step "Adding APT config to tolerate missing repos"
mkdir -p "$BUILD_DIR/config/apt/apt.conf.d"
cat > "$BUILD_DIR/config/apt/apt.conf.d/99ignore-missing-repos" << 'APTEOF'
// Kali rolling has no -updates or -security suites.
// live-build may generate entries for them anyway; let apt continue.
Acquire::AllowInsecureRepositories "false";
APT::Update::Error-Mode "any";
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

# Rootfs overlay (configs, skel, sysctl, etc.)
cp -a "$PROJECT_DIR/kali-config/common/includes.chroot/"* "$BUILD_DIR/config/includes.chroot/" 2>/dev/null || true

# ── Build (staged) ────────────────────────────────────────────────────────────
# We split lb build into bootstrap → chroot → binary so we can inject an apt
# config into the chroot between stages.  live-build's lb_chroot_archives
# generates a sources.list entry for kali-rolling-updates (which 404s) and
# none of the LB_UPDATES patches reach its internal logic.  By writing the
# apt.conf.d file directly into the bootstrapped chroot BEFORE lb chroot runs,
# apt-get update will treat the 404 as a warning, not an error.

step "Stage 1/3: Bootstrap"
lb bootstrap 2>&1 | tee -a "$BUILD_DIR/build.log"

step "Injecting apt config into chroot to tolerate missing repos"
mkdir -p "$BUILD_DIR/chroot/etc/apt/apt.conf.d"
cat > "$BUILD_DIR/chroot/etc/apt/apt.conf.d/99ignore-missing-repos" << 'APTEOF'
// Kali rolling has no -updates or -security suites.
// live-build generates entries for them anyway; let apt continue.
APT::Update::Error-Mode "any";
APTEOF
echo "    Wrote chroot/etc/apt/apt.conf.d/99ignore-missing-repos"

step "Stage 2/3: Chroot (installing packages — this is the slow part)"
lb chroot 2>&1 | tee -a "$BUILD_DIR/build.log"

step "Stage 3/3: Binary (assembling ISO)"
lb binary 2>&1 | tee -a "$BUILD_DIR/build.log"

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
