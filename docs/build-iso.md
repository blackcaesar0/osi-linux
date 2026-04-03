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
sudo apt install git live-build cdebootstrap devscripts
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

Build time: **30–90 minutes** (mostly downloading packages).

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

## Customization

### Packages

Edit `kali-config/variant-osi/package-lists/osi.list.chroot`. One package per line. Lines starting with `#` are comments.

### Desktop configs

Edit files in `config/` — they're copied into `/etc/skel` so every user gets them automatically:

| Config file | Destination in ISO |
|---|---|
| `config/awesome/rc.lua` | `/etc/skel/.config/awesome/rc.lua` |
| `config/alacritty/alacritty.toml` | `/etc/skel/.config/alacritty/alacritty.toml` |
| `config/rofi/osi.rasi` | `/etc/skel/.config/rofi/osi.rasi` |
| `config/picom/picom.conf` | `/etc/skel/.config/picom/picom.conf` |
| `config/tmux/tmux.conf` | `/etc/skel/.tmux.conf` |
| `config/vim/vimrc` | `/etc/skel/.vimrc` |
| `config/shell/bash_aliases` | `/etc/skel/.bash_aliases` |

### Build hooks

Add scripts to `kali-config/common/hooks/live/`. They run inside the chroot during build. Name them with number prefixes for ordering:

- `0010-system-config.hook.chroot` — system-level config
- `0020-desktop-setup.hook.chroot` — desktop and user setup
- `0030-osi-branding.hook.chroot` — branding and cleanup

### Rootfs overlay

Files in `kali-config/common/includes.chroot/` are copied directly into the filesystem. For example:

```
kali-config/common/includes.chroot/etc/motd  →  /etc/motd in the ISO
```

---

## Testing

Test the ISO in QEMU before writing to USB:

```sh
qemu-system-x86_64 \
    -cdrom build/osi-linux-*.iso \
    -m 4G \
    -enable-kvm \
    -boot d \
    -device virtio-vga
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
