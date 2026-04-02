# Post-Install Guide

## First Boot Checklist

Run these checks after the first full reboot into the desktop:

```sh
# Services running
sv status /var/service/*

# Time sync active
sv status /var/service/openntpd

# SPICE agent running (clipboard + auto-resize)
sv status /var/service/spice-vdagent

# QEMU guest agent running
sv status /var/service/qemu-guest-agent

# Network up
ip addr show

# SSH accessible from host (run on host)
ssh youruser@localhost -p 2222

# Python version
python --version    # should show 3.12.x
pyenv versions      # shows all installed

# Ruby version (system)
ruby --version      # should show 3.3.x

# Go
go version

# Pentest tools
nmap --version
tcpdump --version
tshark --version    # requires wireshark group — log out/in after setup

# SPICE clipboard
# Copy text on host, paste with Ctrl+Shift+V in alacritty
```

---

## Directory Layout for Tools

```
~/tools/
├── recon/          host/service discovery, OSINT
├── exploitation/   exploit frameworks, payloads
├── post-exploitation/  privilege escalation, pivoting, persistence
├── web/            web app scanners, proxy configs, wordlists
├── network/        network sniffers, MitM, lateral movement
├── forensics/      memory analysis, file carving, log analysis
├── custom/         scripts and tools you write yourself
└── wordlists/      SecLists, rockyou, custom wordlists
```

---

## Installing Tools

### Python tools (via pipx — isolated, no virtualenv needed)

```sh
# Impacket (SMB/Kerberos/LDAP tools)
pipx install impacket

# Crackmapexec
pipx install crackmapexec

# Netexec (CME fork)
pipx install netexec

# Bloodhound ingester
pipx install bloodhound

# Certipy (AD CS attacks)
pipx install certipy-ad
```

### Go tools

```sh
# gobuster
go install github.com/OJ/gobuster/v3@latest

# ffuf
go install github.com/ffuf/ffuf/v2@latest

# nuclei
go install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest

# httpx
go install github.com/projectdiscovery/httpx/cmd/httpx@latest

# subfinder
go install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
```

Installed binaries land in `~/go/bin/` which is on PATH.

### Ruby tools (via gem — uses system Ruby)

```sh
# evil-winrm
gem install evil-winrm

# WPScan
gem install wpscan
```

### Metasploit Framework

Metasploit requires Ruby and several gems. The recommended approach:

```sh
cd ~/tools/exploitation
git clone https://github.com/rapid7/metasploit-framework
cd metasploit-framework
gem install bundler
bundle install
# Run with: ./msfconsole
```

Or use the nightly installer script (reads from rapid7 repo, not xbps):

```sh
curl https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb > msfinstall
chmod +x msfinstall
./msfinstall
```

### Burp Suite

Download the community edition JAR from portswigger.net and run with:

```sh
mkdir -p ~/tools/web/burpsuite
cd ~/tools/web/burpsuite
# Place burpsuite_community.jar here
java -jar burpsuite_community.jar
```

---

## Wordlists

```sh
# SecLists (comprehensive)
cd ~/tools/wordlists
git clone --depth 1 https://github.com/danielmiessler/SecLists .

# rockyou.txt (if not already present)
# Often available compressed in security repos, or extract from Kali
```

---

## Keeping the System Updated

```sh
sudo xbps-install -Su         # update all packages
pyenv update                  # update pyenv itself
pip install --user --upgrade pipx  # update pipx
```
