#!/bin/bash
# Run as root inside the guest after first boot.
set -euo pipefail

step() { echo; echo "==> $*"; }

step "Updating package database and system"
xbps-install -Syu -y

# Enable nonfree repo (needed for some packages)
xbps-install -y void-repo-nonfree
xbps-install -Sy -y

# Core system utilities
step "Installing core utilities"
xbps-install -y \
    curl wget git vim nano \
    bash-completion man-pages \
    openssh dbus dbus-x11 \
    xdg-utils xdg-user-dirs \
    tmux screen \
    jq yq \
    zip unzip p7zip \
    rsync file tree

# Build essentials
step "Installing build tools"
xbps-install -y \
    gcc make cmake patch \
    autoconf automake libtool pkg-config \
    binutils glibc-devel linux-headers \
    git-lfs

# Development headers (needed for pyenv Python builds, gem native extensions, etc.)
step "Installing development headers"
xbps-install -y \
    openssl-devel \
    libffi-devel \
    zlib-devel \
    bzip2-devel \
    readline-devel \
    sqlite-devel \
    liblzma-devel \
    ncurses-devel \
    tk-devel \
    libpcap-devel \
    libnet-devel \
    libnetfilter_queue-devel \
    libnl3-devel \
    libnfnetlink-devel \
    mit-krb5-devel \
    libssh2-devel \
    libxml2-devel \
    libxslt-devel \
    libyaml-devel \
    postgresql-libs-devel \
    sqlite \
    gdbm-devel

# Runtimes
step "Installing runtimes"
xbps-install -y \
    python3 python3-devel python3-pip python3-setuptools python3-wheel \
    ruby ruby-devel \
    go \
    openjdk17 openjdk17-jre \
    nodejs \
    perl

# Fonts
step "Installing fonts"
xbps-install -y \
    dejavu-fonts-ttf \
    font-hack-ttf \
    noto-fonts-ttf \
    noto-fonts-emoji

# QEMU/SPICE guest integration
step "Installing QEMU/SPICE guest tools"
xbps-install -y \
    qemu-ga \
    spice-vdagent

# Pentest networking and scanning
step "Installing pentest tools"
xbps-install -y \
    nmap masscan \
    tcpdump wireshark \
    socat \
    net-tools iproute2 \
    bind-utils whois traceroute

# Binary analysis, debugging, monitoring
step "Installing debug and monitoring tools"
xbps-install -y \
    strace ltrace gdb \
    lsof htop iotop pciutils usbutils sysstat \
    openntpd

# Enable system services
step "Enabling core services"
ln -sf /etc/sv/dbus  /var/service/
ln -sf /etc/sv/sshd  /var/service/

# Add wheel group members to wireshark group for tshark without root
getent group wireshark &>/dev/null && {
    getent group wheel | cut -d: -f4 | tr ',' '\n' | while read -r u; do
        [ -n "$u" ] && usermod -aG wireshark "$u" 2>/dev/null || true
    done
}

echo ""
echo "==> Base setup complete."
