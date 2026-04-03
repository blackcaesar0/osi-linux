# Building an ISO

`scripts/build-iso.sh` produces a hybrid bootable ISO from the same source tree used for the VM install. The ISO boots from USB or optical media and runs a live session directly from RAM.

---

## Host Prerequisites

In addition to the bootstrap prerequisites, you need:

| Tool | Package (Debian/Ubuntu) |
|------|------------------------|
| `mksquashfs` | `squashfs-tools` |
| `xorriso` | `xorriso` |
| `grub-mkrescue` | `grub2-common` or `grub-common` |
| `dracut` | `dracut` |

Install:
```sh
# Debian/Ubuntu
sudo apt install squashfs-tools xorriso grub2-common dracut

# Arch
sudo pacman -S squashfs-tools xorriso grub dracut

# Fedora
sudo dnf install squashfs-tools xorriso grub2-tools dracut
```

---

## Building

```sh
sudo bash scripts/build-iso.sh
# or with a custom output path:
sudo bash scripts/build-iso.sh ~/releases/osi-linux-custom.iso
```

The output ISO is placed at `~/VM/osi-linux-YYYYMMDD.iso` by default and is owned by your real user.

Build time: 30–60 minutes depending on download speed and CPU.

### Environment variable overrides

| Variable | Default | Purpose |
|----------|---------|---------|
| `REPO` | Void default mirror | Void Linux package mirror URL |
| `WORK_DIR` | `/tmp/osi-iso-work` | Scratch space for the build |

Example:
```sh
sudo REPO=https://mirrors.dotsrc.org/voidlinux/current bash scripts/build-iso.sh
```

---

## What the Script Does

1. Downloads static xbps (same as bootstrap.sh)
2. Creates a clean rootfs and bootstraps Void Linux base into it
3. Runs `base-setup.sh` and `desktop-setup.sh` inside a chroot
4. Installs `dracut` and `dracut-live`, then builds a live-boot initramfs using the `dmsquash-live` module
5. Packs the rootfs into a compressed squashfs image
6. Assembles the ISO directory structure with GRUB boot config
7. Calls `grub-mkrescue` to produce a hybrid EFI+BIOS ISO
8. Prints the SHA256 checksum of the output

---

## Requirement: dmsquash-live

The `dmsquash-live` dracut module is **required** for live ISO boot. The build script attempts to install `dracut-live` automatically inside the chroot, then checks for the module. If it is still missing, the build **errors out** rather than producing an unbootable ISO.

If you hit this error:

**Option A — Use void-mklive (recommended)**

The Void Linux project provides `void-mklive`, a set of scripts specifically designed for building Void live images. It handles the initramfs internally without relying on dmsquash-live.

```sh
git clone https://github.com/void-linux/void-mklive
cd void-mklive
# See its README for usage — point it at a custom package list
```

**Option B — Manual initramfs**

Write a minimal `init` script that mounts the squashfs and overlays a tmpfs, then pack it with `cpio`. This is what void-mklive does internally.

---

## Testing the ISO

Before writing to USB, test with QEMU:

```sh
qemu-system-x86_64 \
    -cdrom ~/VM/osi-linux-$(date +%Y%m%d).iso \
    -m 4G \
    -enable-kvm \
    -boot d \
    -vga qxl
```

---

## Writing to USB

Find your USB device with `lsblk`, then:

```sh
sudo dd if=~/VM/osi-linux-YYYYMMDD.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

Replace `/dev/sdX` with your actual USB device. This overwrites everything on the device.

Verify the write: `sha256sum /dev/sdX` and compare against the checksum printed at the end of the build.

---

## Customising the ISO

- To change what packages are installed: edit `scripts/base-setup.sh` and `scripts/desktop-setup.sh` before running the ISO build
- To change the live session user: the rootfs will contain the `osi` user with the default password set during bootstrap — the ISO does not run bootstrap interactively, so the live user uses whatever password is baked in via `chpasswd` in `base-setup.sh`
- To add files to the ISO root: place them in the `iso/` directory before the `grub-mkrescue` step
- The GRUB config is written inline in `build-iso.sh` — edit it there to change boot options or add menu entries
