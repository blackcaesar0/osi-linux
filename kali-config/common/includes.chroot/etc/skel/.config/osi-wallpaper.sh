#!/bin/sh
# OSI Linux — set the OSI-Noir wallpaper on every active monitor.
#
# Our shipped xfce4-desktop.xml uses the xfconf key "monitorVirtual-0", which
# matches the xrandr output name on virtio-gpu under SPICE. On other backends
# (real hardware, qxl, vmware, plain VGA std) the connector name differs and
# xfconf silently falls back to the XFCE default blue polygon wallpaper.
#
# This script walks every backdrop property xfconf-query already knows about
# and forces it to /usr/share/backgrounds/osi/osi.png. Runs at every XFCE
# session start; cheap and idempotent.
set -eu

WALL="/usr/share/backgrounds/osi/osi.png"
[ -r "$WALL" ] || exit 0

command -v xfconf-query >/dev/null 2>&1 || exit 0

# Find every backdrop image property and overwrite it.
xfconf-query -c xfce4-desktop -l 2>/dev/null | grep '/last-image$' | while read -r prop; do
    xfconf-query -c xfce4-desktop -p "$prop" -s "$WALL" 2>/dev/null || true
done

# Also set the image-style to "Zoom" (5) so it covers any aspect ratio.
xfconf-query -c xfce4-desktop -l 2>/dev/null | grep '/image-style$' | while read -r prop; do
    xfconf-query -c xfce4-desktop -p "$prop" -s 5 2>/dev/null || true
done

# Ask xfdesktop to redraw.
command -v xfdesktop >/dev/null 2>&1 && xfdesktop --reload >/dev/null 2>&1 || true
