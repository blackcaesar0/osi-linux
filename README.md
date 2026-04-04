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
- **QEMU/KVM optimized** — virtio-gpu, virtio-scsi, virtio-net, SPICE audio, balloon, RNG
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
sudo apt install git live-build simple-cdd cdebootstrap devscripts

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

The SPICE display opens automatically. Clipboard and auto-resize work out of the box.

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

## QEMU/KVM Details

The VM runs with:

| Component | Configuration |
|-----------|--------------|
| Machine | q35 + KVM acceleration |
| CPU/RAM | 4 cores / 2 threads, 8 GB (configurable) |
| Boot | UEFI (OVMF) |
| Disk | virtio-scsi, writeback cache, discard |
| Display | **virtio-gpu** + SPICE with GL acceleration |
| Clipboard | SPICE vdagent (auto, bidirectional) |
| Auto-resize | virtio-gpu + udev + xrandr (instant) |
| Network | virtio-net, SSH forwarded on port 2222 |
| Audio | intel-hda via SPICE |
| USB | SPICE USB redirection (2 channels) |
| Memory | virtio-balloon (dynamic) |
| Entropy | virtio-rng (no entropy starvation) |

### Environment overrides

```sh
VM_CORES=8 VM_THREADS=2 VM_RAM=16G ./launch-vm.sh
DISK_IMAGE=~/VM/custom.qcow2 ./launch-vm.sh
NO_GL=1 ./launch-vm.sh    # headless host, use: spicy -h 127.0.0.1 -p 5900
```

### VM troubleshooting

If something breaks inside the guest:

```sh
fix-display      # re-trigger xrandr auto-resize
fix-clipboard    # restart spice-vdagent
```

---

## Project Structure

```
osi-linux/
├── build.sh                 Build script (wraps Kali live-build)
├── launch-vm.sh             QEMU/KVM launcher (virtio-gpu + SPICE)
├── config/                  Desktop configs (xfce4, tmux, vim, shell)
├── kali-config/
│   ├── variant-osi/
│   │   └── package-lists/   Curated package selection
│   └── common/
│       ├── hooks/live/      Build-time config hooks
│       │   ├── 0010-system-config     System tuning + SPICE + virtio-gpu
│       │   ├── 0015-qemu-guest-fixes  10 QEMU/KVM bug fixes
│       │   ├── 0020-desktop-setup     XFCE + user + LightDM
│       │   └── 0030-osi-branding      Branding + wallpaper + cleanup
│       └── includes.chroot/ Files overlaid into the rootfs
├── scripts/
│   ├── create-vm.sh         Create qcow2 disk + boot installer
│   └── cleanup-host.sh      Remove build artifacts
├── wallpaper/               OSI wallpaper
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
