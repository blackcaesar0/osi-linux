#!/bin/bash
DISK="$HOME/VM/osi-linux.qcow2"
PIDFILE="/tmp/osi-vm.pid"
ISO="${1:-}"

if [ -f "$PIDFILE" ]; then
    OLD_PID=$(cat "$PIDFILE")
    if kill -0 "$OLD_PID" 2>/dev/null; then
        echo "VM already running (PID $OLD_PID). Kill it first: kill $OLD_PID"
        exit 1
    fi
    rm -f "$PIDFILE"
fi

DRIVE_ARGS="-drive file=$DISK,if=none,id=disk0,format=qcow2 -device virtio-scsi-pci,id=scsi0 -device scsi-hd,drive=disk0,bus=scsi0.0"

if [ -n "$ISO" ]; then
    DRIVE_ARGS="$DRIVE_ARGS -drive file=$ISO,media=cdrom,readonly=on"
    BOOT="-boot order=dc"
else
    BOOT="-boot order=c"
fi

qemu-system-x86_64 \
    -enable-kvm \
    -cpu host \
    -smp cores=4,threads=2 \
    -m 8G \
    $DRIVE_ARGS \
    $BOOT \
    -device virtio-vga \
    -spice port=5900,addr=127.0.0.1,disable-ticketing=on \
    -device virtio-serial-pci,id=virtio-serial0 \
    -chardev spicevmc,id=vdagent,name=vdagent \
    -device virtserialport,chardev=vdagent,name=com.redhat.spice.0,bus=virtio-serial0.0 \
    -chardev socket,path=/tmp/qga.sock,server=on,wait=off,id=qga0 \
    -device virtserialport,chardev=qga0,name=org.qemu.guest_agent.0,bus=virtio-serial0.0,nr=2 \
    -netdev user,id=net0,hostfwd=tcp::2222-:22 \
    -device virtio-net-pci,netdev=net0 \
    -netdev user,id=net1,restrict=on \
    -device virtio-net-pci,netdev=net1 \
    -usb \
    -device usb-tablet \
    -device usb-ehci,id=ehci0 \
    -chardev spicevmc,name=usbredir,id=usbredir0 \
    -device usb-redir,chardev=usbredir0,id=redirect0,bus=ehci0.0 \
    -chardev spicevmc,name=usbredir,id=usbredir1 \
    -device usb-redir,chardev=usbredir1,id=redirect1,bus=ehci0.0 \
    -daemonize \
    -pidfile "$PIDFILE"
