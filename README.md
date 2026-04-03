# OSI Linux

A custom Kali-based distribution built for penetration testing and offensive security operations. Runs as a QEMU/KVM virtual machine with full SPICE integration, or boots from USB.

XFCE desktop with OSI team branding, curated tool selection, copy/paste and auto-resize working out of the box.

---

## Features

- **Kali rolling base** — access to Kali's entire tool repository via `apt`
- **XFCE desktop** — clean, familiar desktop with OSI dark theme
- **Copy/paste works immediately** — SPICE vdagent + clipman, no configuration needed
- **Auto-resize display** — resize the SPICE window and the guest follows instantly
- **OSI team theme** — dark base with custom branding, Papirus-Dark icons, Hack font
- **SPICE + QEMU guest agent** — clipboard sharing, display auto-resize, USB redirection
- **Curated tools** — metasploit, nmap, burpsuite, bloodhound, impacket, hashcat, ghidra, and more
- **Development ready** — Python 3, Ruby, Go, Node.js, Java, full build toolchain
- **Live ISO** — boot from USB or run in QEMU, install to disk when ready
- **Everything baked in** — no post-install scripts, it just works

---

## Quick Start

### Option 1: Build the ISO

Requires a Debian, Ubuntu, or Kali host.

```sh
git clone https://github.com/blackcaesar0/osi-linux
cd osi-linux

# Install prerequisites
sudo apt install git live-build cdebootstrap devscripts

# Build the ISO
sudo ./build.sh
```

Build takes 30-90 minutes. The ISO lands in `build/`.

### Option 2: Run in QEMU/KVM

```sh
# Create a VM disk and boot the ISO installer
bash scripts/create-vm.sh build/osi-linux-*.iso

# After installing, boot normally
./launch-vm.sh
```

Connect to the VM: `spicy -h 127.0.0.1 -p 5900`

### Option 3: Write to USB

```sh
sudo dd if=build/osi-linux-*.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

---

## Default Credentials

| User | Password | Notes |
|------|----------|-------|
| `osi` | `osi` | Desktop user with passwordless sudo |
| `root` | `toor` | Root account |

**Change these after first login:** `passwd`

---

## Project Structure

```
osi-linux/
├── build.sh                 Build script (wraps Kali live-build)
├── launch-vm.sh             QEMU/KVM launcher
├── config/                  Desktop configs (xfce4, tmux, vim, shell)
├── kali-config/
│   ├── variant-osi/
│   │   └── package-lists/   Curated package selection
│   └── common/
│       ├── hooks/live/      Build-time config hooks
│       └── includes.chroot/ Files overlaid into the rootfs
├── scripts/
│   ├── create-vm.sh         Create qcow2 disk + boot installer
│   └── cleanup-host.sh      Remove build artifacts
├── wallpaper/               OSI wolf logo
└── docs/
```

---

## Customizing

### Add/remove packages

Edit `kali-config/variant-osi/package-lists/osi.list.chroot` — one package per line.

### Change desktop configs

Edit files in `config/` — they're copied into `/etc/skel` during build so every user gets them.

### Add build-time configuration

Add hook scripts in `kali-config/common/hooks/live/` — they run inside the chroot during ISO build. Name them with number prefixes for ordering (e.g., `0040-my-hook.hook.chroot`).

### Add files to the rootfs

Place files in `kali-config/common/includes.chroot/` — they're overlaid directly onto the filesystem. For example, `includes.chroot/etc/foo.conf` becomes `/etc/foo.conf` in the ISO.

---

## QEMU/KVM Details

The VM runs with:
- KVM acceleration, q35 machine type
- 8 GB RAM, 4 cores / 2 threads
- UEFI boot (OVMF)
- virtio-scsi disk, virtio-net networking
- SPICE display with clipboard + USB redirect
- Audio via SPICE (intel-hda)
- SSH forwarded on host port 2222
