#!/bin/bash
# Run as root inside the guest.
set -e

xbps-install -y \
    nmap wireshark tcpdump netcat socat \
    sqlmap hydra john hashcat \
    aircrack-ng \
    ffuf gobuster dirb masscan nikto \
    binwalk foremost \
    gdb radare2 \
    strace ltrace \
    whois bind-utils \
    net-tools iproute2 \
    openvpn wireguard-tools \
    tor proxychains-ng \
    smbclient \
    net-snmp-tools \
    tmux screen \
    jq \
    p7zip unrar zip unzip \
    neovim \
    openjdk17 \
    android-tools

echo "Tier 1 tools installed."
