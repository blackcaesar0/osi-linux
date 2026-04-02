# OSI Linux

A custom Void Linux distribution built from scratch for penetration testing and daily use inside QEMU/KVM. No systemd — runit only. Minimal tiling desktop (awesome WM) with full SPICE integration for clipboard sharing and auto-resize. Designed to be built by anyone, on any host.

---

## Features

- Void Linux (glibc, rolling release, runit init)
- awesome WM with OSI black/white branding and named workspaces
- SPICE + QEMU guest agent for clipboard, drag-and-drop, and display auto-resize
- X11 session with picom compositor, alacritty terminal, rofi launcher
- Multi-version Python (3.9–3.12) via pyenv, Ruby 3.3 via rbenv, pipx for isolated CLI tools
- Go workspace, Node.js, OpenJDK 17, Perl pre-installed
- Complete build toolchain and 30+ development headers for compiling any pentest tool from source
- Essential network tools: nmap, masscan, tcpdump, tshark, socat, ncat, wireshark, bind-tools
- Binary analysis: strace, ltrace, gdb, lsof, vim-common (xxd), binutils
- ranger file manager, mousepad editor, zathura PDF viewer, slock screen lock
- tmux config (Ctrl+a prefix, vi keys, OSI status bar), vim config (no plugins), bash aliases
- Organised `~/tools/` directory tree with workspace README stubs
- openntpd time sync, tuned sysctl (scanner-friendly socket buffers, high inotify limits)
- Passwordless sudo for the default user (standard for pentest VMs)
- ISO build script producing a USB-dd-able hybrid live image

---

## Host Requirements

| Tool | Purpose |
|------|---------|
| `qemu-kvm` / `qemu-system-x86_64` | VM execution |
| `qemu-img` | Create and manage qcow2 disk images |
| `qemu-nbd` | Mount qcow2 for bootstrap |
| `sgdisk` (gdisk) | GPT partitioning |
| `partprobe` (parted) | Refresh partition table |
| `mkfs.fat`, `mkfs.ext4` | Format partitions |
| `curl` | Download static xbps |
| `blkid`, `udevadm` | Device detection |
| `spicy` or `virt-viewer` | SPICE client (to connect to the VM display) |

Install on Debian/Ubuntu: `sudo apt install qemu-kvm qemu-utils gdisk parted dosfstools e2fsprogs curl util-linux udevil virt-viewer`

Install on Arch: `sudo pacman -S qemu-full gptfdisk parted dosfstools e2fsprogs curl virt-viewer`

---

## Quick Start

```sh
git clone <repo> osi-linux
cd osi-linux

# 1. Create disk and bootstrap Void Linux onto it (host, as root)
sudo bash scripts/bootstrap.sh

# 2. Start the VM
./launch-vm.sh

# Connect to the VM display with: spicy -h localhost -p 5900
# Or open virt-viewer and connect to spice://localhost:5900
```

Inside the VM, log in as root and run the setup scripts in order:

```sh
# Copy the project into the VM first (or mount via SPICE shared folder)
# Then run as root:
bash /path/to/osi-linux/scripts/base-setup.sh
bash /path/to/osi-linux/scripts/desktop-setup.sh

# Then as the osi user:
export BASE="$HOME/osi-setup"   # adjust if project is elsewhere
bash "$BASE/scripts/deploy-configs.sh"

sudo reboot
```

See [docs/install.md](docs/install.md) for the full step-by-step walkthrough.

---

## Setup Script Order

| Script | Run as | Where | What it does |
|--------|--------|-------|--------------|
| `scripts/bootstrap.sh` | root | host | Partition disk, bootstrap Void, install GRUB |
| `scripts/base-setup.sh` | root | guest | Packages, build tools, runtimes, pentest tools |
| `scripts/desktop-setup.sh` | root | guest | Xorg, awesome WM, desktop apps, display manager |
| `scripts/deploy-configs.sh` | osi | guest | Configs, shell env, version managers, icon theme |
| ↳ `scripts/sysconfig.sh` | root | guest | sysctl, sudoers, openntpd, resource limits |
| ↳ `scripts/version-managers.sh` | osi | guest | pyenv, rbenv, Python 3.9–3.12, Ruby 3.3, pipx |
| ↳ `scripts/shell-env.sh` | osi | guest | bash_aliases, vimrc, tmux.conf, prompt |
| ↳ `scripts/setup-icons.sh` | osi | guest | Custom OSI icon theme |

---

## Configuration Variables

`bootstrap.sh` reads these environment variables (all have defaults):

`bootstrap.sh` prompts for username and passwords interactively. The following can also be set via environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `DISK_IMAGE` | `~/VM/osi-linux.qcow2` | Path for the qcow2 disk image |
| `DISK_SIZE` | `80G` | Disk image size |
| `VM_HOSTNAME` | `osi` | Guest hostname |

Example: `sudo DISK_SIZE=120G bash scripts/bootstrap.sh`

---

## Building an ISO

```sh
sudo bash scripts/build-iso.sh [output.iso]
```

See [docs/build-iso.md](docs/build-iso.md) for prerequisites and full details.

---

## Directory Layout

```
osi-linux/
├── config/
│   ├── alacritty/      terminal emulator config
│   ├── awesome/        rc.lua + theme.lua
│   ├── ly/             display manager config
│   ├── picom/          compositor config
│   ├── rofi/           launcher theme
│   ├── runit/          spice-vdagent + qemu-guest-agent services
│   ├── shell/          bash_aliases
│   ├── tmux/           tmux.conf
│   └── vim/            vimrc
├── docs/               install, ISO build, post-install, keybindings
├── scripts/            bootstrap, setup, deploy, build-iso
├── wallpaper/          osi.png (wolf logo)
├── launch-vm.sh        QEMU launch command
└── README.md
```
