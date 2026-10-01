# Building the OSI Linux ISO

## How It Works

OSI Linux uses [Kali's live-build](https://www.kali.org/docs/development/live-build-a-custom-kali-iso/) infrastructure to produce a bootable hybrid ISO. The `build.sh` script:

1. Installs the Kali archive keyring if missing
2. Runs `lb config` with Kali rolling repos
3. Copies our package list, hooks, and rootfs overlay into the build tree
4. Runs `lb build` to produce the ISO

The result is a standard Debian/Kali live ISO that:
- Boots into a live session (all tools available, changes lost on reboot)
- Can install to disk via the Kali installer
- Works on bare metal, QEMU/KVM, VirtualBox, VMware

---

## Prerequisites

**Host:** Debian 12+, Ubuntu 22.04+, or Kali Linux.

```sh
sudo apt install git live-build simple-cdd cdebootstrap devscripts
```

**Disk space:** ~30 GB free (build chroot + squashfs + ISO).

**Kali keyring:** If not on Kali, the build script installs it automatically. Manual install:

```sh
curl -fsSL https://archive.kali.org/archive-key.asc \
    | sudo gpg --dearmor -o /usr/share/keyrings/kali-archive-keyring.gpg
```

---

## Building

```sh
sudo ./build.sh
```

Build time: **30-90 minutes** (mostly downloading packages).

### Options

```sh
sudo ./build.sh --verbose           # show all output
sudo ./build.sh --clean             # remove previous build first
sudo ./build.sh --output ~/my.iso   # custom output path
```

### Rebuilding

After changing configs or packages:

```sh
sudo ./build.sh --clean
```

The `--clean` flag runs `lb clean --purge` before building.

---

## Build Hooks

The ISO is configured by chroot hooks that run during build. They execute in numeric order:

| Hook | Purpose |
|------|---------|
| `0010-system-config` | sysctl tuning, resource limits, virtio module loading, service enablement, GRUB timeout |
| `0015-qemu-guest-fixes` | SPICE clipboard and auto-resize, virtio-gpu, Xorg, audio, DNS, journald caps, `fix-display` / `fix-clipboard` / `clip` / `osi-update` helpers |
| `0020-desktop-setup` | XFCE session, OSI-Noir GTK settings, font rendering, LightDM autologin, live user, workspace tree |
| `0030-osi-branding` | `os-release`, issue/MOTD banners, wallpaper fallbacks, menu glyph, clipman autostart, apt cleanup |
| `0031-grub-theme` | GRUB 2 OSI-Noir theme (text and 1px rules only, so it renders on any firmware) |
| `0035-osi-noir-theme` | Seeds and desaturates xfwm4 pixmaps, mono icon folders, system-wide GTK defaults, icon caches |
| `0040-pentest-setup` | Metasploit database, pip/proxychains/SSH client config, shell helper functions, wordlists |
| `0050-first-boot` | One-shot service: regenerates SSH host keys per install, initialises the Metasploit DB, then removes itself |

Hooks run inside the chroot in numeric order, **after** the `includes.chroot`
overlay has been applied. A hook that writes a file unconditionally therefore
overwrites whatever the overlay shipped at that path — prefer writing a
fallback only when the file is absent.

### Where live-build looks for hooks

live-build changed the local-hook location between releases:

| live-build | Local hook path |
|---|---|
| older (e.g. Ubuntu's 3.x) | `config/hooks/*.chroot` |
| newer (Debian/Kali, 2021+) | `config/hooks/live/*.chroot` |

`build.sh` detects which layout the installed live-build actually scans and
stages the hooks there, then hard-fails if fewer than all of them land. This
matters more than it looks: copying hooks into a directory live-build never
reads means **zero** hooks run and the build still reports success — the ISO
just silently ships with no OSI user, theme, branding or SPICE fixes.

---

## Customization

### Packages

Edit `kali-config/variant-osi/package-lists/osi.list.chroot`. One package per line. Lines starting with `#` are comments.

### Desktop configs

Edit files in `config/` — they're copied into `/etc/skel` so every user gets them automatically:

| Config file | Destination in ISO |
|---|---|
| `config/xfce4/terminal/terminalrc` | `/etc/skel/.config/xfce4/terminal/terminalrc` |
| `config/xfce4/xfconf/xfce-perchannel-xml/*.xml` | `/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/` |
| `config/tmux/tmux.conf` | `/etc/skel/.tmux.conf` |
| `config/vim/vimrc` | `/etc/skel/.vimrc` |
| `config/shell/bash_aliases` | `/etc/skel/.bash_aliases` |

### Build hooks

Add scripts to `kali-config/common/hooks/live/`. They run inside the chroot during build. Name them with number prefixes for ordering (e.g., `0040-my-hook.hook.chroot`).

### Rootfs overlay

Files in `kali-config/common/includes.chroot/` are copied directly into the filesystem. For example:

```
kali-config/common/includes.chroot/etc/motd  ->  /etc/motd in the ISO
```

---

## Quality Gates

Before pushing a change, run the full check suite:

```sh
make check
```

It runs three gates, all of which also run in CI:

| Gate | What it enforces |
|------|------------------|
| `make lint` | Every shell script parses (`bash -n`) and is shellcheck-clean at warning severity |
| `make check-theme` | Every colour in a theme file is grayscale, and `config/` matches its `/etc/skel` mirror |
| `make check-repo` | Build hooks are executable and the package list has no duplicates |
| `make check-packages` | Every package still exists in kali-rolling (needs network) |

The theme gate exists because OSI-Noir is specified as strict black-and-white.
A copied snippet or an upstream default can quietly reintroduce an accent
colour, so the rule is checked rather than trusted. If you intentionally
change a config under `config/`, run `make sync-skel` to update the overlay
copy.

---

## Testing

Test the ISO in QEMU before writing to USB:

```sh
# Quick test (no disk, live session only)
qemu-system-x86_64 \
    -cdrom build/osi-linux-*.iso \
    -m 4G \
    -enable-kvm \
    -boot d \
    -device virtio-gpu-pci

# Full test with disk and SPICE
bash scripts/create-vm.sh build/osi-linux-*.iso
```

---

## Cleanup

Remove build artifacts (can be 20+ GB):

```sh
bash scripts/cleanup-host.sh
```

Or manually:

```sh
sudo rm -rf build/
```
