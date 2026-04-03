# Installation Guide

## Host Prerequisites

You need a Linux host with KVM support. Check with: `ls /dev/kvm` — if the file exists, KVM is available.

**Debian / Ubuntu:**
```sh
sudo apt install \
    qemu-kvm qemu-utils \
    parted \
    dosfstools e2fsprogs \
    curl util-linux udev \
    grub-efi-amd64-bin \
    ovmf virt-viewer
```

**Arch Linux:**
```sh
sudo pacman -S qemu-full parted dosfstools e2fsprogs curl edk2-ovmf virt-viewer
```

**Fedora / RHEL:**
```sh
sudo dnf install qemu-kvm qemu-img parted dosfstools e2fsprogs curl grub2-efi-x64 edk2-ovmf virt-viewer
```

Make sure your user is in the `kvm` group: `sudo usermod -aG kvm $USER` (then log out and back in).

---

## Step 1: Clone the Repository

```sh
git clone <repo> osi-linux
cd osi-linux
```

---

## Step 2: Bootstrap

This creates the qcow2 disk image, installs a minimal Void Linux base system, and embeds the setup scripts into the VM so they are ready to run on first boot.

```sh
sudo bash scripts/bootstrap.sh
```

You will be prompted for username, keyboard layout, root password, and user password. The script then:

1. Downloads the static xbps binary to `~/VM/bootstrap/`
2. Creates an 80 GB raw disk, partitions it (512 MB EFI + rest root ext4)
3. Bootstraps Void Linux base into the root partition
4. Configures hostname, locale, fstab, user accounts
5. Builds a standalone UEFI boot binary (BOOTX64.EFI) with embedded GRUB config
6. Copies the osi-setup scripts into `/home/$VM_USER/osi-setup` inside the VM
7. Converts the raw disk to qcow2 format

Bootstrap takes 5–10 minutes depending on your connection speed.

### Environment variable overrides

| Variable | Default | Purpose |
|----------|---------|---------|
| `DISK_SIZE` | `80G` | Size of the disk image |
| `DISK_IMAGE` | `~/VM/osi-linux.qcow2` | Output path for the qcow2 |
| `VM_HOSTNAME` | `osi` | Hostname inside the VM |
| `REPO` | Void default mirror | Void Linux package mirror URL |
| `TZ` | `UTC` | Timezone |

Example:
```sh
sudo DISK_SIZE=120G VM_HOSTNAME=pentest REPO=https://mirrors.dotsrc.org/voidlinux/current bash scripts/bootstrap.sh
```

---

## Step 3: Start the VM

```sh
./launch-vm.sh
```

Connect to the display using a SPICE client:

```sh
spicy -h localhost -p 5900
# or
virt-viewer spice://localhost:5900
```

At the login prompt, log in as `root` with the password you set during bootstrap.

### VM resource overrides

| Variable | Default | Purpose |
|----------|---------|---------|
| `DISK_IMAGE` | `~/VM/osi-linux.qcow2` | Disk image to boot |
| `VM_CORES` | `4` | CPU cores |
| `VM_THREADS` | `2` | Threads per core |
| `VM_RAM` | `8G` | RAM |

Example:
```sh
VM_CORES=8 VM_RAM=16G ./launch-vm.sh
```

---

## Step 4: Base System Setup (as root inside the guest)

The setup scripts are already inside the VM at `~/osi-setup`. No file transfer needed.

```sh
sudo bash ~/osi-setup/scripts/base-setup.sh
```

This installs all packages: build tools, development headers, runtimes (Python, Ruby, Go, Node, Java, Perl), QEMU/SPICE guest tools, and essential pentest tools (nmap, tcpdump, wireshark, socat, etc.).

Takes 3–5 minutes.

---

## Step 5: Desktop Setup (as root inside the guest)

```sh
sudo bash ~/osi-setup/scripts/desktop-setup.sh
```

This installs Xorg, QXL video driver, awesome WM, alacritty, rofi, picom, emptty display manager, Firefox, ranger, mousepad, zathura, flameshot, and slock. It also enables NetworkManager and emptty services.

Takes 2–4 minutes.

---

## Step 6: Deploy Configs (as your desktop user, NOT root)

```sh
bash ~/osi-setup/scripts/deploy-configs.sh
```

**Important:** Run this as your desktop user, not as root.

This script calls several sub-scripts automatically:

- Copies all config files (awesome, alacritty, rofi, picom, tmux, vim)
- Deploys runit service scripts for spice-vdagent and qemu-guest-agent
- Creates `~/.xinitrc` for dbus-launch + awesome session
- Runs `sysconfig.sh` (kernel params, sudoers, NTP, resource limits)
- Cleans up any leftover rbenv installation
- Runs `version-managers.sh` (pyenv, Python 3.9–3.12, pipx, system Ruby)
- Runs `shell-env.sh` (bash aliases, prompt, workspace READMEs)
- Runs `setup-icons.sh` (custom OSI icon theme)

Python version compilation takes 10–20 minutes total. This is normal.

To install specific Python versions instead of the defaults:
```sh
PYTHON_VERSIONS="3.11.9 3.12.3" PYTHON_GLOBAL=3.12.3 bash ~/osi-setup/scripts/version-managers.sh
```

---

## Step 7: Reboot

```sh
sudo reboot
```

After reboot, emptty starts on TTY7. Log in with your username and password. The X session launches awesome WM automatically via `~/.xinitrc`.

---

## Verification Checklist

After first boot into the desktop:

- awesome WM starts with OSI theme (black background, white accents)
- OSI wolf wallpaper is set
- Workspaces show names: OSI, term, web, tools, recon, exploit, post, files, misc
- `Win+Return` opens alacritty
- `Win+d` opens rofi launcher
- `Win+e` opens ranger in a terminal
- `Win+Ctrl+l` locks the screen with slock
- SPICE clipboard works: copy text on host, paste in guest terminal
- `python --version` shows 3.12.x
- `ruby --version` shows 3.3.x
- `go version` works
- `nmap --version` works
- `ssh youruser@localhost -p 2222` from host connects successfully
