#!/bin/bash
# Run as root inside the guest.
# Installs Xorg, awesome WM, desktop apps, and enables display manager.
set -euo pipefail

step() { echo; echo "==> $*"; }

step "Installing Xorg and video drivers"
xbps-install -y \
    xorg-minimal xorg-input-drivers \
    xf86-video-fbdev xf86-video-qxl \
    xorg-server xorg-server-common xinit \
    mesa-dri

step "Installing awesome WM and desktop tools"
xbps-install -y \
    awesome \
    alacritty \
    rofi \
    picom \
    feh \
    papirus-icon-theme \
    ImageMagick \
    scrot flameshot \
    xclip xdotool \
    noto-fonts-ttf noto-fonts-emoji \
    xsettingsd \
    ranger mousepad \
    zathura zathura-pdf-mupdf \
    xterm slock

step "Installing network management"
xbps-install -y \
    NetworkManager \
    network-manager-applet

step "Installing display manager (emptty)"
xbps-install -y emptty

# Configure emptty for direct xinitrc launch
mkdir -p /etc/emptty
cat > /etc/emptty/conf << 'EOF'
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
EOF

step "Installing Firefox"
xbps-install -y firefox

step "Enabling services"
ln -sf /etc/sv/NetworkManager   /var/service/
ln -sf /etc/sv/emptty           /var/service/
ln -sf /etc/sv/spice-vdagent    /var/service/ 2>/dev/null || true
ln -sf /etc/sv/qemu-guest-agent /var/service/ 2>/dev/null || true

echo ""
echo "==> Desktop packages installed."
