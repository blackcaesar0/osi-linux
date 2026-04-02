#!/bin/bash
# Run as osi inside the guest.
# Deploys all configs and prepares the environment for tool installation.
set -euo pipefail

BASE="$HOME/osi-setup"

# ── Config directories ────────────────────────────────────────────────────────
mkdir -p \
    ~/.config/awesome \
    ~/.config/alacritty \
    ~/.config/rofi \
    ~/.config/picom \
    ~/wallpaper \
    ~/.local/bin \
    ~/bin

# ── Copy configs ──────────────────────────────────────────────────────────────
cp "$BASE/config/awesome/rc.lua"            ~/.config/awesome/
cp "$BASE/config/awesome/theme.lua"         ~/.config/awesome/
cp "$BASE/config/alacritty/alacritty.toml"  ~/.config/alacritty/
cp "$BASE/config/rofi/osi.rasi"             ~/.config/rofi/
cp "$BASE/config/picom/picom.conf"          ~/.config/picom/
cp "$BASE/wallpaper/osi.png"                ~/wallpaper/

# ── System configs (needs root) ───────────────────────────────────────────────
sudo cp "$BASE/config/ly/config.ini" /etc/ly/config.ini

sudo cp -r "$BASE/config/runit/spice-vdagent"    /etc/sv/
sudo cp -r "$BASE/config/runit/qemu-guest-agent" /etc/sv/
sudo chmod +x /etc/sv/spice-vdagent/run /etc/sv/qemu-guest-agent/run
sudo ln -sf /etc/sv/spice-vdagent    /var/service/ 2>/dev/null || true
sudo ln -sf /etc/sv/qemu-guest-agent /var/service/ 2>/dev/null || true

# ── .xinitrc ──────────────────────────────────────────────────────────────────
cat > ~/.xinitrc << 'EOF'
#!/bin/sh
export XDG_SESSION_TYPE=x11
export XDG_RUNTIME_DIR=/run/user/$(id -u)
mkdir -p "$XDG_RUNTIME_DIR"
exec dbus-launch --exit-with-session awesome
EOF
chmod +x ~/.xinitrc

# ── PATH ──────────────────────────────────────────────────────────────────────
grep -q '.local/bin' ~/.bashrc || \
    echo 'export PATH="$HOME/.local/bin:$HOME/bin:$PATH"' >> ~/.bashrc

# ── Tools directory structure ─────────────────────────────────────────────────
# Pre-create standard layout so any tool dropped in has a home
mkdir -p ~/tools/{recon,exploitation,post-exploitation,web,network,forensics,custom,wordlists}

# Symlink Go workspace to a predictable location
mkdir -p ~/go/{bin,pkg,src}
grep -q 'GOPATH' ~/.bashrc || cat >> ~/.bashrc << 'EOF'

# Go
export GOPATH="$HOME/go"
export PATH="$GOPATH/bin:$PATH"
EOF

# ── GOPATH bin on PATH for this session too ───────────────────────────────────
export GOPATH="$HOME/go"
export PATH="$HOME/.local/bin:$HOME/bin:$GOPATH/bin:$PATH"

# ── Version managers ──────────────────────────────────────────────────────────
bash "$BASE/scripts/version-managers.sh"

# ── Icon theme ────────────────────────────────────────────────────────────────
bash "$BASE/scripts/setup-icons.sh"

echo ""
echo "==> Deploy complete. Verify awesome WM config:"
echo "    awesome -k ~/.config/awesome/rc.lua"
echo ""
echo "==> Reboot when ready: sudo reboot"
