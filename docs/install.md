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

This creates the qcow2 disk image and installs a minimal Void Linux base system onto it. Run as root on the host.

```sh
sudo bash scripts/bootstrap.sh
```

You will be prompted for username, keyboard layout, root password, and user password. The script then:

1. Downloads the static xbps binary to `~/VM/bootstrap/`
2. Creates an 80 GB raw disk, partitions it (512 MB EFI + rest root ext4)
3. Bootstraps Void Linux base into the root partition
4. Configures hostname, locale, fstab, user accounts
5. Builds a standalone UEFI boot binary (BOOTX64.EFI) with embedded GRUB config
6. Converts the raw disk to qcow2 format

To customise disk size or hostname:

```sh
sudo DISK_SIZE=120G VM_HOSTNAME=pentest bash scripts/bootstrap.sh
```

Bootstrap takes 5–10 minutes depending on your connection speed.

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

---

## Step 4: Transfer the Project into the Guest

The easiest way is SSH (forwarded on host port 2222):

```sh
# From the host:
scp -P 2222 -r osi-linux/ youruser@localhost:~/osi-setup/
```

Or use a shared directory via SPICE file transfer, or a USB image mount — any method works.

---

## Step 5: Base System Setup (as root inside the guest)

```sh
bash ~/osi-setup/scripts/base-setup.sh
```

This installs all packages: build tools, development headers, runtimes (Python, Ruby, Go, Node, Java, Perl), QEMU/SPICE guest tools, and essential pentest tools (nmap, tcpdump, wireshark, socat, etc.).

Takes 3–5 minutes.

---

## Step 6: Desktop Setup (as root inside the guest)

```sh
bash ~/osi-setup/scripts/desktop-setup.sh
```

This installs Xorg, QXL video driver, awesome WM, alacritty, rofi, picom, emptty display manager, Firefox, ranger, mousepad, zathura, flameshot, and slock. It also enables NetworkManager, emptty, spice-vdagent, and qemu-guest-agent services.

Takes 2–4 minutes.

---

## Step 7: Deploy Configs (as your desktop user, NOT root)

```sh
bash ~/osi-setup/scripts/deploy-configs.sh
```

**Important:** Run this as your desktop user, not as root.

This script calls several sub-scripts automatically:

- Copies all config files (awesome, alacritty, rofi, picom, tmux, vim)
- Creates `~/.xinitrc` for dbus-launch + awesome session
- Runs `sysconfig.sh` (kernel params, sudoers, NTP, resource limits)
- Cleans up any leftover rbenv installation
- Runs `version-managers.sh` (pyenv, Python 3.9–3.12, pipx, system Ruby)
- Runs `shell-env.sh` (bash aliases, prompt, workspace READMEs)
- Runs `setup-icons.sh` (custom OSI icon theme)

Python version compilation takes 10–20 minutes total. This is normal.

---

## Step 8: Reboot

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
