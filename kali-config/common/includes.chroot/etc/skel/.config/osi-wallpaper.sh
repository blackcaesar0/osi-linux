#!/bin/sh
# OSI Linux — set the OSI-Noir wallpaper on every active monitor.
#
# Our shipped xfce4-desktop.xml uses the xfconf key "monitorVirtual-0", which
# matches the xrandr output name on virtio-gpu under SPICE. On other backends
# (real hardware, qxl, vmware, plain VGA std) the connector name differs and
# xfconf silently falls back to the XFCE default blue polygon wallpaper.
#
# This script walks every backdrop property xfconf-query already knows about
# and points it at /usr/share/backgrounds/osi/osi.png.
#
# It runs ONCE, not on every login. Forcing the wallpaper at every session start
# meant a user who picked one of the other shipped OSI-Noir wallpapers — which
# the README documents how to do — silently got it reverted on their next login.
# Marker-based, matching the pattern osi-firefox-init.sh already uses.
set -eu

WALL="/usr/share/backgrounds/osi/osi.png"
MARKER="$HOME/.config/osi-wallpaper.done"

[ -e "$MARKER" ] && exit 0
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

# Done — never override the user's choice again.
mkdir -p "$(dirname "$MARKER")"
: > "$MARKER"
