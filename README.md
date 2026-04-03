# OSI Linux

A custom Kali-based distribution built for penetration testing and offensive security operations. Runs as a QEMU/KVM virtual machine with full SPICE integration, or boots from USB.

Leaner than stock Kali — awesome WM tiling desktop, curated tool selection, cyberpunk dark theme, QEMU/KVM optimized out of the box.

---

## Features

- **Kali rolling base** — access to Kali's entire tool repository via `apt`
- **awesome WM** — fast tiling desktop with 9 named workspaces, no XFCE/GNOME bloat
- **Cyberpunk theme** — dark base with cyan accents across all apps (alacritty, rofi, tmux, vim)
- **SPICE + QEMU guest agent** — clipboard sharing, display auto-resize, USB redirection
- **Curated tools** — metasploit, nmap, burpsuite, bloodhound, impacket, hashcat, ghidra, and more
- **Development ready** — Python 3, Ruby, Go, Node.js, Java, full build toolchain
- **picom compositor** — blur, shadows, rounded corners, smooth fading
- **Live ISO** — boot from USB or run in QEMU, install to disk when ready
- **Everything pre-configured** — no post-install scripts to run, it just works

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

Build takes 30–90 minutes. The ISO lands in `build/`.

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

## Desktop Keybindings

Mod key = Super (Win).

| Key | Action |
|-----|--------|
| `Mod+Return` | Terminal (alacritty) |
| `Mod+d` | App launcher (rofi) |
| `Mod+e` | File manager (ranger) |
| `Mod+1-9` | Switch workspace |
| `Mod+Shift+c` | Close window |
| `Mod+f` | Fullscreen |
| `Mod+s` | Show all keybindings |
| `Mod+Ctrl+l` | Lock screen |
| `Print` | Screenshot |
| `Shift+Print` | Screenshot (select region) |

See [docs/keybindings.md](docs/keybindings.md) for the complete reference.

---

## Project Structure

```
osi-linux/
├── build.sh                 Build script (wraps Kali live-build)
├── launch-vm.sh             QEMU/KVM launcher
├── config/                  Desktop configs (awesome, alacritty, rofi, picom, tmux, vim)
├── kali-config/
│   ├── variant-osi/
│   │   └── package-lists/   Curated package selection
│   └── common/
│       ├── hooks/live/      Build-time config hooks
│       ├── includes.chroot/ Files overlaid into the rootfs
│       └── includes.binary/ Files on the ISO media
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

---

## Why OSI over stock Kali?

| | Stock Kali | OSI Linux |
|---|---|---|
| Desktop | XFCE (heavy) | awesome WM (fast, tiling) |
| Tools | 600+ (bloated) | Curated essentials |
| ISO size | ~4 GB | ~2-3 GB |
| VM integration | Basic | Full SPICE + guest agent |
| Theme | Kali blue | Cyberpunk dark + cyan |
| Post-install | Manual config | Pre-configured |
