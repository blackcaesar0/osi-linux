# Post-Install Guide

## First Boot Checklist

```sh
# Services
systemctl status ssh spice-vdagentd qemu-guest-agent NetworkManager

# Network
ip addr show

# SSH from host
ssh osi@localhost -p 2222

# Clipboard test — copy text on host, then:
xclip -selection clipboard -o    # should show host clipboard content

# Display resize — drag the SPICE window edge, guest should follow

# Tools
nmap --version
msfconsole --version
sqlmap --version
hashcat --version
python3 --version
ruby --version
go version
```

---

## VM Troubleshooting

### Display stuck at wrong resolution

```sh
fix-display
```

Or manually:

```sh
xrandr --output Virtual-0 --auto
xrandr --output Virtual-1 --auto    # try alternate output names
```

### Clipboard not working

```sh
fix-clipboard
```

Or manually:

```sh
# Check if spice-vdagentd is running (system daemon)
systemctl status spice-vdagentd

# Restart it if needed
sudo systemctl restart spice-vdagentd

# Check if spice-vdagent is running (user agent)
pgrep spice-vdagent || spice-vdagent &
```

### Audio crackling or no sound

PulseAudio is pre-tuned for VM use. If you still hear crackling:

```sh
# Check audio devices
pactl list sinks short

# Adjust buffer size
pulseaudio -k && pulseaudio --start
```

---

## Installing More Kali Tools

The biggest advantage of being Kali-based: every tool is one `apt install` away.

### Kali metapackages

```sh
# Install all web application testing tools
sudo apt install kali-tools-web

# Install all exploitation tools
sudo apt install kali-tools-exploitation

# Install all information gathering tools
sudo apt install kali-tools-information-gathering

# Install all vulnerability analysis tools
sudo apt install kali-tools-vulnerability

# Install ALL Kali tools (warning: ~15 GB)
sudo apt install kali-linux-everything
```

### Individual tools

```sh
# More recon
sudo apt install subfinder nuclei httpx-toolkit

# More exploitation
sudo apt install covenant powersploit

# Wireless (for USB WiFi passthrough)
sudo apt install wifite kismet fern-wifi-cracker

# Forensics
sudo apt install autopsy sleuthkit

# Reporting
sudo apt install cutycapt eyewitness faraday
```

---

## Go Tools (not in Kali repos)

```sh
go install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
go install github.com/projectdiscovery/httpx/cmd/httpx@latest
go install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
```

Binaries land in `~/go/bin/` which is on PATH.

---

## Python Tools (via pipx)

```sh
pipx install certipy-ad
pipx install netexec
pipx install pwntools
```

---

## Directory Layout

```
~/tools/
├── recon/              host/service discovery, OSINT
├── exploitation/       exploit frameworks, payloads
├── post-exploitation/  privesc, pivoting, persistence
├── web/                web app scanners, proxy configs
├── network/            sniffers, MitM, lateral movement
├── forensics/          memory analysis, file carving
├── custom/             your own scripts and tools
└── wordlists/          SecLists, rockyou, custom lists
```

---

## Keeping Updated

```sh
# Update everything
sudo apt update && sudo apt full-upgrade -y

# Update Go tools
go install github.com/OJ/gobuster/v3@latest
# ... etc

# Update pipx tools
pipx upgrade-all
```

---

## Docker

Docker is pre-installed. Start it with:

```sh
sudo systemctl start docker
sudo usermod -aG docker osi   # then log out/in
```

Useful for running tools in isolated containers:

```sh
docker run -it kalilinux/kali-rolling /bin/bash
```
