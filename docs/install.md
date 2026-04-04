# Installation Guide

## Build Prerequisites

You need a **Debian, Ubuntu, or Kali** host with at least 30 GB free disk space.

```sh
sudo apt install git live-build simple-cdd cdebootstrap devscripts
```

If building on a non-Kali host, you also need the Kali archive keyring. The build script installs it automatically, or you can do it manually:

```sh
curl -fsSL https://archive.kali.org/archive-key.asc | sudo gpg --dearmor -o /usr/share/keyrings/kali-archive-keyring.gpg
```

---

## Building the ISO

```sh
git clone https://github.com/blackcaesar0/osi-linux
cd osi-linux
sudo ./build.sh
```

Options:

| Flag | Default | Description |
|------|---------|-------------|
| `--verbose` | off | Show all build output |
| `--clean` | off | Clean previous build first |
| `--output <path>` | `build/osi-linux-*.iso` | Custom output path |

Build takes 30-90 minutes depending on bandwidth and CPU. The ISO is a hybrid image (bootable from USB or optical media).

---

## Running in QEMU/KVM

### Step 1: Create the VM

```sh
bash scripts/create-vm.sh build/osi-linux-*.iso
```

This creates an 80 GB qcow2 disk at `~/VM/osi-linux.qcow2` and boots the ISO.

### Step 2: Install (or use live session)

The ISO boots into a live session. You can:

- **Use it live** — everything works, changes are lost on reboot
- **Install to disk** — use the Kali installer to write to the qcow2 disk

### Step 3: Boot the installed system

After installing and shutting down:

```sh
./launch-vm.sh
```

The SPICE display opens automatically with GL acceleration. Clipboard and auto-resize work immediately.

### No-GL mode (headless hosts)

If your host has no GPU or GL support:

```sh
NO_GL=1 ./launch-vm.sh
```

Then connect manually:

```sh
spicy -h 127.0.0.1 -p 5900
```

### SSH from host

```sh
ssh osi@localhost -p 2222
```

### VM resource overrides

```sh
VM_CORES=8 VM_THREADS=2 VM_RAM=16G ./launch-vm.sh
DISK_IMAGE=~/VM/custom.qcow2 ./launch-vm.sh
DISK_SIZE=120G bash scripts/create-vm.sh build/osi-linux-*.iso
```

---

## Writing to USB

```sh
sudo dd if=build/osi-linux-*.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

Replace `/dev/sdX` with your USB device (check with `lsblk`).

---

## After Installation

1. **Change default passwords:**
   ```sh
   passwd          # change osi password
   sudo passwd     # change root password
   ```

2. **Update the system:**
   ```sh
   sudo apt update && sudo apt upgrade -y
   ```

3. **Install additional Kali tools:**
   ```sh
   sudo apt install kali-tools-web          # all web tools
   sudo apt install kali-tools-exploitation  # all exploitation tools
   ```

4. **Check services:**
   ```sh
   systemctl status ssh spice-vdagentd qemu-guest-agent NetworkManager
   ```

---

## Verification Checklist

After first boot, verify:

- [ ] XFCE desktop starts with OSI dark theme
- [ ] OSI wallpaper is displayed
- [ ] `Ctrl+Alt+T` opens terminal
- [ ] SPICE clipboard works (copy on host, Ctrl+V in guest and vice versa)
- [ ] Display auto-resizes when you resize the SPICE window
- [ ] `nmap --version` works
- [ ] `msfconsole` launches Metasploit
- [ ] `ssh osi@localhost -p 2222` from host works
- [ ] Audio works (try `speaker-test -t wav -c 2`)

### If something doesn't work

```sh
fix-display      # re-trigger xrandr (fixes stuck resolution)
fix-clipboard    # restart spice-vdagent (fixes broken clipboard)
```
