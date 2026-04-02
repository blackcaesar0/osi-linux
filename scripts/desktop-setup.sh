#!/bin/bash
# Run as root inside the guest.
set -euo pipefail

xbps-install -y \
    xorg-minimal xorg-input-drivers xf86-video-fbdev \
    xorg-server xorg-server-common xinit \
    awesome \
    alacritty \
    rofi \
    picom \
    feh \
    ly \
    papirus-icon-theme \
    ImageMagick \
    scrot \
    xclip xdotool \
    noto-fonts-ttf noto-fonts-emoji \
    NetworkManager \
    network-manager-applet \
    firefox \
    xsettingsd \
    ranger mousepad \
    zathura zathura-pdf-mupdf \
    xterm xfce-icon-theme slock

ln -sf /etc/sv/NetworkManager /var/service/
ln -sf /etc/sv/ly /var/service/

echo "Desktop packages installed."
