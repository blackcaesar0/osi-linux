#!/bin/bash
# Run as root inside the guest after first boot.
set -e

xbps-install -Su

xbps-install -y \
    curl wget git vim nano \
    bash-completion man-pages \
    openssh dbus \
    spice-vdagent qemu-guest-agent \
    xdg-utils xdg-user-dirs \
    dejavu-fonts-ttf \
    font-jetbrains-mono

ln -sf /etc/sv/dbus /var/service/
ln -sf /etc/sv/sshd /var/service/

echo "Base setup done."
