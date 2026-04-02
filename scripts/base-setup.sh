#!/bin/bash
# Run as root inside the guest after first boot.
set -euo pipefail

xbps-install -Su

# Core system utilities
xbps-install -y \
    curl wget git vim nano \
    bash-completion man-pages \
    openssh dbus dbus-x11 \
    spice-vdagent qemu-guest-agent \
    xdg-utils xdg-user-dirs \
    tmux screen \
    jq yq \
    zip unzip p7zip \
    rsync

# Build essentials — needed to compile any tool from source
xbps-install -y \
    gcc gcc-c++ make cmake \
    autoconf automake libtool pkg-config \
    binutils glibc-devel linux-headers \
    git-lfs

# Development headers — covers 95% of tool build requirements
xbps-install -y \
    openssl-devel \
    libffi-devel \
    zlib-devel \
    bzip2-devel \
    readline-devel \
    sqlite-devel \
    xz-devel \
    ncurses-devel \
    tk-devel \
    libpcap-devel \
    libnet-devel \
    libnetfilter_queue-devel \
    libnl3-devel \
    libnfnetlink-devel \
    krb5-devel \
    libssh2-devel \
    libxml2-devel \
    libxslt-devel \
    postgresql-libs-devel \
    sqlite

# Runtimes
xbps-install -y \
    python3 python3-devel python3-pip python3-setuptools python3-wheel \
    ruby ruby-devel \
    go \
    openjdk17 openjdk17-jre \
    nodejs npm \
    perl

# Fonts
xbps-install -y \
    dejavu-fonts-ttf \
    font-jetbrains-mono \
    noto-fonts-ttf \
    noto-fonts-emoji

# Enable system services
ln -sf /etc/sv/dbus  /var/service/
ln -sf /etc/sv/sshd  /var/service/

echo "==> Base setup complete."
