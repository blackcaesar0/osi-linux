# OSI Linux

OSI stands for **(OSI) Offensive Security Initiative**. A custom Kali-based distribution built for penetration testing and offensive security operations, tuned for QEMU/KVM with full SPICE integration. Boots from USB or runs as a VM.

XFCE desktop with the **OSI-Noir** cyber-noir theme: strict black-and-white, glitch and grain motifs, no chroma. Copy/paste and auto-resize work out of the box.

---

## Features

- **Kali rolling base** — full Kali tool repository via `apt`
- **OSI-Noir theme** — strict B&W cyber-noir aesthetic across GRUB, Plymouth, LightDM, GTK 3/4, xfwm4, terminal, and Firefox chrome. No real-world logos, no Guy Fawkes masks, no chroma
- **QEMU/KVM optimized** — virtio-gpu, virtio-scsi, virtio-net, SPICE audio, balloon, RNG, qemu-guest-agent enabled, virtio modules pre-loaded into initramfs
- **Copy/paste + auto-resize out of the box** — SPICE vdagent autostart, hardened `osi-resize` udev hook (handles Xorg + Xwayland)
- **Force-rotate default credentials** — `osi:osi` / `root:toor` are pre-expired; PAM blocks any sudo/login until the password is changed
- **Curated tools** — metasploit, nmap, burpsuite, bloodhound, impacket, hashcat, ghidra, and more
- **Development ready** — Python 3, Ruby, Go, Node.js, Java, full build toolchain
- **Live ISO** — boot from USB or run in QEMU, install to disk when ready
- **Hardened build** — atomic apt-get wrapper with lockfile, post-build ISO validation (size, volume descriptor, El Torito boot record, kernel/initrd presence, SHA256 sidecar)

---

## Theme — OSI-Noir

Cyber-noir, hacker realism, digital decay, data-world abstraction. Strict black-and-white (limited grayscale only when symbolic or for clarity) — never full color. Backgrounds are mostly black with intentional negative space. Glitches, scanlines, grain, ASCII texture and circuit patterns are all allowed; comic styles, real-world logos, Guy Fawkes masks, and full-spectrum color are not.

The theme is layered everywhere a user sees pixels:

| Layer | Implementation |
|---|---|
| Boot loader | `OSI-Noir` GRUB 2 theme — white-on-black, inverted-selection accent, no images |
| Boot splash | `osi-noir` Plymouth theme — animated ASCII grain + thin progress bar, no logo |
| Login screen | LightDM GTK greeter on `OSI-Noir` GTK theme + B&W wallpaper |
| Desktop wallpaper | `osi-noir-network.png` (default) — abstract network graph dissolving into glitch. Alts: `cat` (silhouette reading code), `terminal` (corrupted ASCII waterfall), `grain` (texture overlay) |
| GTK 3 / 4 | Custom `OSI-Noir` theme overlaying Adwaita-dark; every accent color forced to white-on-black |
| Window manager | `OSI-Noir` xfwm4 theme — desaturated borders, white active title text, gray inactive |
| Terminal | xfce4-terminal palette mapped to a 16-step grayscale ramp; pure black background |
| Firefox chrome | `userChrome.css` dropped into the active profile on first login by `osi-firefox-init.sh` |
| Console / TTY | Mono ASCII banners in `/etc/issue` and `/etc/motd` — no color escapes |

Switch wallpapers from XFCE Settings → Desktop, or directly:

```sh
xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitorVirtual-0/workspace0/last-image \
  -s /usr/share/backgrounds/osi/osi-noir-cat.png
```

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

Both passwords are **immediately expired** — the first `sudo`, `su`, console login, or SSH login will refuse to proceed until the password is changed (`passwd` is invoked automatically by PAM). Auto-login still works for the GUI session, but nothing privileged runs until you rotate the password.

**Manually rotate at any time:** `passwd`

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
