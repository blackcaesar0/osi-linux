#!/bin/bash
# Run as root inside the guest after first boot.
set -euo pipefail

xbps-install -Su

# Core system utilities
xbps-install -y \
    curl wget git vim nano \
    bash-completion man-pages \
    openssh dbus dbus-x11 \
    spice-vdagent \
    xdg-utils xdg-user-dirs \
    tmux screen \
    jq yq \
    zip unzip p7zip \
    rsync

# Build essentials
# Note: gcc in Void includes C++ support — no separate gcc-c++ package
xbps-install -y \
    gcc make cmake \
    autoconf automake libtool pkg-config \
    binutils glibc-devel linux-headers \
    git-lfs

# Development headers
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

# Pentest networking and scanning
xbps-install -y \
    nmap masscan \
    tcpdump wireshark \
    socat \
    net-tools iproute2 \
    bind-tools whois traceroute

# Binary analysis, debugging, monitoring
# Note: xxd ships inside the vim package — no vim-common in Void
# Note: ncat is included in the nmap package
xbps-install -y \
    strace ltrace gdb \
    lsof htop iotop pciutils usbutils sysstat \
    openntpd

# Enable system services
ln -sf /etc/sv/dbus  /var/service/
ln -sf /etc/sv/sshd  /var/service/

# Add wheel group members to wireshark group for tshark without root
getent group wheel | cut -d: -f4 | tr ',' '\n' | while read -r u; do
    [ -n "$u" ] && usermod -aG wireshark "$u" 2>/dev/null || true
done

echo "==> Base setup complete."
