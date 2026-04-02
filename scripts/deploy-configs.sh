#!/bin/bash
# Run as osi inside the guest.
# Copies all configs from ~/osi-setup into the right locations.
set -e

BASE="$HOME/osi-setup"

mkdir -p \
    ~/.config/awesome \
    ~/.config/alacritty \
    ~/.config/rofi \
    ~/.config/picom \
    ~/wallpaper \
    ~/bin

cp "$BASE/config/awesome/rc.lua"            ~/.config/awesome/
cp "$BASE/config/awesome/theme.lua"         ~/.config/awesome/
cp "$BASE/config/alacritty/alacritty.toml"  ~/.config/alacritty/
cp "$BASE/config/rofi/osi.rasi"             ~/.config/rofi/
cp "$BASE/config/picom/picom.conf"          ~/.config/picom/
cp "$BASE/wallpaper/osi.png"                ~/wallpaper/

# Deploy ly config (needs root)
sudo cp "$BASE/config/ly/config.ini" /etc/ly/config.ini

# Deploy runit services (needs root)
sudo cp -r "$BASE/config/runit/spice-vdagent"   /etc/sv/
sudo cp -r "$BASE/config/runit/qemu-guest-agent" /etc/sv/
sudo chmod +x /etc/sv/spice-vdagent/run
sudo chmod +x /etc/sv/qemu-guest-agent/run
sudo ln -sf /etc/sv/spice-vdagent   /var/service/ 2>/dev/null || true
sudo ln -sf /etc/sv/qemu-guest-agent /var/service/ 2>/dev/null || true

# .xinitrc
cat > ~/.xinitrc << 'EOF'
#!/bin/sh
export XDG_SESSION_TYPE=x11
export XDG_RUNTIME_DIR=/run/user/$(id -u)
mkdir -p "$XDG_RUNTIME_DIR"
exec dbus-launch --exit-with-session awesome
EOF
chmod +x ~/.xinitrc

grep -q '.local/bin' ~/.bashrc || echo 'export PATH="$HOME/.local/bin:$HOME/bin:$PATH"' >> ~/.bashrc
mkdir -p ~/tools

echo "Configs deployed. Run: awesome -k ~/.config/awesome/rc.lua to verify."
