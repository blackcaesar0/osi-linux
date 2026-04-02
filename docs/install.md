# Installation Guide

## Host Prerequisites

You need a Linux host with KVM support. Check with: `ls /dev/kvm` — if the file exists, KVM is available.

**Debian / Ubuntu:**
```sh
sudo apt install \
    qemu-kvm qemu-utils \
    gdisk parted \
    dosfstools e2fsprogs \
    curl util-linux udev \
    virt-viewer
```

**Arch Linux:**
```sh
sudo pacman -S qemu-full gptfdisk parted dosfstools e2fsprogs curl virt-viewer
```

**Fedora / RHEL:**
```sh
sudo dnf install qemu-kvm qemu-img gdisk parted dosfstools e2fsprogs curl virt-viewer
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

You will be prompted for root and user passwords before anything else happens. The script then:

1. Downloads the static xbps binary to `~/VM/bootstrap/`
2. Creates an 80 GB qcow2 disk at `~/VM/osi-linux.qcow2`
3. Connects the disk via NBD and partitions it (512 MB EFI + rest root ext4)
4. Bootstraps Void Linux base into the root partition
5. Configures hostname, locale, fstab, user accounts
6. Installs GRUB for EFI boot

To customise disk size, hostname, or username:

```sh
sudo DISK_SIZE=120G VM_HOSTNAME=pentest VM_USER=operator bash scripts/bootstrap.sh
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
scp -P 2222 -r osi-linux/ osi@localhost:~/osi-setup/
```

Or use a shared directory via SPICE file transfer, or a USB image mount — any method works.

---

## Step 5: Base System Setup (as root inside the guest)

```sh
bash ~/osi-setup/scripts/base-setup.sh
```

This installs all packages: build tools, development headers, runtimes (Python, Ruby, Go, Node, Java, Perl), and essential pentest networking tools (nmap, tcpdump, wireshark, socat, etc.).

Takes 3–5 minutes.

---

## Step 6: Desktop Setup (as root inside the guest)

```sh
bash ~/osi-setup/scripts/desktop-setup.sh
```

This installs Xorg, awesome WM, alacritty, rofi, picom, ly display manager, Firefox, ranger, mousepad, zathura, and slock.

Takes 2–4 minutes.

---

## Step 7: Deploy Configs (as osi inside the guest)

Log in as `osi`, then:

```sh
bash ~/osi-setup/scripts/deploy-configs.sh
```

This script calls several sub-scripts automatically:

- Copies all config files (awesome, alacritty, rofi, picom, tmux, vim, ly)
- Runs `sysconfig.sh` (kernel params, sudoers, NTP, resource limits)
- Runs `version-managers.sh` (pyenv, rbenv, Python 3.9–3.12, Ruby 3.3, pipx)
- Runs `shell-env.sh` (bash aliases, prompt, workspace READMEs)
- Runs `setup-icons.sh` (custom OSI icon theme)

Python version compilation takes 10–20 minutes total. This is normal.

---

## Step 8: Reboot

```sh
sudo reboot
```

After reboot, the `ly` display manager starts on TTY2. Log in as `osi` and the X session launches automatically.

---

## Verification Checklist

After first boot into the desktop:

- awesome WM starts without errors in `~/.xsession-errors`
- Workspaces show names: term, web, tools, recon, exploit, post, files, misc, scratch
- `Win+Return` opens alacritty
- `Win+d` opens rofi launcher
- `Win+e` opens ranger in a terminal
- `Win+Ctrl+l` locks the screen with slock
- SPICE clipboard works: copy text on host, paste in guest terminal
- `python --version` shows 3.12.x
- `ruby --version` shows 3.3.x
- `go version` works
- `nmap --version` works
- `ssh osi@localhost -p 2222` from host connects successfully
