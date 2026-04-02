#!/bin/bash
# Run as osi inside the guest.
set -euo pipefail

ICON_DIR="$HOME/.icons/osi-icons"

mkdir -p ~/.config/gtk-3.0 ~/.config/gtk-4.0

cat > ~/.config/gtk-3.0/settings.ini << 'EOF'
[Settings]
gtk-icon-theme-name=osi-icons
gtk-theme-name=Adwaita-dark
gtk-font-name=Hack 10
EOF
cp ~/.config/gtk-3.0/settings.ini ~/.config/gtk-4.0/settings.ini

mkdir -p "$ICON_DIR"/{16x16,32x32,48x48,64x64,128x128}/apps \
         "$ICON_DIR/scalable/apps"

cat > "$ICON_DIR/index.theme" << 'EOF'
[Icon Theme]
Name=osi-icons
Comment=OSI team icon theme
Inherits=Papirus-Dark
Directories=16x16/apps,32x32/apps,48x48/apps,64x64/apps,128x128/apps,scalable/apps

[16x16/apps]
Size=16
Type=Fixed

[32x32/apps]
Size=32
Type=Fixed

[48x48/apps]
Size=48
Type=Fixed

[64x64/apps]
Size=64
Type=Fixed

[128x128/apps]
Size=128
Type=Fixed

[scalable/apps]
Size=48
MinSize=8
MaxSize=512
Type=Scalable
EOF

for SIZE in 16 32 48 64 128; do
    convert ~/wallpaper/osi.png -resize "${SIZE}x${SIZE}" \
        "$ICON_DIR/${SIZE}x${SIZE}/apps/Alacritty.png"
    convert ~/wallpaper/osi.png -resize "${SIZE}x${SIZE}" \
        "$ICON_DIR/${SIZE}x${SIZE}/apps/burpsuite.png"
    convert ~/wallpaper/osi.png -resize "${SIZE}x${SIZE}" \
        "$ICON_DIR/${SIZE}x${SIZE}/apps/metasploit.png"
    convert ~/wallpaper/osi.png -resize "${SIZE}x${SIZE}" \
        "$ICON_DIR/${SIZE}x${SIZE}/apps/firefox.png"
done
cp ~/wallpaper/osi.png "$ICON_DIR/scalable/apps/Alacritty.png"

gtk-update-icon-cache -f "$ICON_DIR" 2>/dev/null || true
gtk-update-icon-cache -f /usr/share/icons/Papirus-Dark 2>/dev/null || true

echo "Icon theme configured."
