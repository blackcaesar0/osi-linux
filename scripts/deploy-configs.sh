#!/bin/bash
# Run as the desktop user (NOT root) inside the guest.
# Deploys all configs and prepares the environment for tool installation.
set -euo pipefail

# Guard: do not run as root
if [ "$(id -u)" -eq 0 ]; then
    echo "ERROR: Run as your desktop user, not root."
    echo "Usage: bash scripts/deploy-configs.sh"
    exit 1
fi

BASE="$(cd "$(dirname "$0")/.." && pwd)"
DESKTOP_USER="$USER"
export DESKTOP_USER

step() { echo; echo "==> $*"; }

# ── Config directories ────────────────────────────────────────────────────────
step "Creating config directories"
mkdir -p \
    ~/.config/awesome \
    ~/.config/alacritty \
    ~/.config/rofi \
    ~/.config/picom \
    ~/.config/tmux \
    ~/wallpaper \
    ~/.local/bin \
    ~/bin

# ── Copy configs ──────────────────────────────────────────────────────────────
step "Deploying awesome WM config"
cp "$BASE/config/awesome/rc.lua"            ~/.config/awesome/
cp "$BASE/config/awesome/theme.lua"         ~/.config/awesome/

step "Deploying application configs"
cp "$BASE/config/alacritty/alacritty.toml"  ~/.config/alacritty/
cp "$BASE/config/rofi/osi.rasi"             ~/.config/rofi/
cp "$BASE/config/picom/picom.conf"          ~/.config/picom/
cp "$BASE/wallpaper/osi.png"                ~/wallpaper/

# ── Runit service scripts ────────────────────────────────────────────────────
step "Deploying runit service scripts"
sudo cp -r "$BASE/config/runit/spice-vdagent"    /etc/sv/ 2>/dev/null || true
sudo cp -r "$BASE/config/runit/qemu-guest-agent"  /etc/sv/ 2>/dev/null || true
sudo chmod +x /etc/sv/spice-vdagent/run    2>/dev/null || true
sudo chmod +x /etc/sv/qemu-guest-agent/run 2>/dev/null || true
sudo ln -sf /etc/sv/spice-vdagent    /var/service/ 2>/dev/null || true
sudo ln -sf /etc/sv/qemu-guest-agent /var/service/ 2>/dev/null || true

# ── System configuration (kernel params, sudoers, ntp, limits) ────────────────
step "Applying system configuration"
sudo bash "$BASE/scripts/sysconfig.sh"

# ── .xinitrc ──────────────────────────────────────────────────────────────────
step "Creating .xinitrc"
cat > ~/.xinitrc << 'EOF'
#!/bin/sh
export XDG_SESSION_TYPE=x11
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
mkdir -p "$XDG_RUNTIME_DIR"
exec dbus-launch --exit-with-session awesome
EOF
chmod +x ~/.xinitrc

# ── PATH ──────────────────────────────────────────────────────────────────────
grep -q '.local/bin' ~/.bashrc 2>/dev/null || \
    echo 'export PATH="$HOME/.local/bin:$HOME/bin:$PATH"' >> ~/.bashrc

# ── Tools directory structure ─────────────────────────────────────────────────
step "Creating tools directory structure"
mkdir -p ~/tools/{recon,exploitation,post-exploitation,web,network,forensics,custom,wordlists}
cp "$BASE/config/tmux/tmux.conf" ~/.tmux.conf

# ── Go workspace ──────────────────────────────────────────────────────────────
mkdir -p ~/go/{bin,pkg,src}
grep -q 'GOPATH' ~/.bashrc 2>/dev/null || cat >> ~/.bashrc << 'EOF'

# Go
export GOPATH="$HOME/go"
export PATH="$GOPATH/bin:$PATH"
EOF

export GOPATH="$HOME/go"
export PATH="$HOME/.local/bin:$HOME/bin:$GOPATH/bin:$PATH"

# ── Clean up leftover rbenv if present ────────────────────────────────────────
if [ -d "$HOME/.rbenv" ]; then
    step "Removing leftover rbenv (using system Ruby instead)"
    rm -rf "$HOME/.rbenv"
    sed -i '/rbenv/d' ~/.bashrc 2>/dev/null || true
fi

# ── Version managers ──────────────────────────────────────────────────────────
step "Setting up version managers"
bash "$BASE/scripts/version-managers.sh"

# ── Shell environment ─────────────────────────────────────────────────────────
step "Setting up shell environment"
bash "$BASE/scripts/shell-env.sh"

# ── Icon theme ────────────────────────────────────────────────────────────────
step "Setting up icon theme"
bash "$BASE/scripts/setup-icons.sh"

echo ""
echo "============================================"
echo "  Deploy complete!"
echo "============================================"
echo ""
echo "  Verify awesome config:  awesome -k ~/.config/awesome/rc.lua"
echo "  Reboot when ready:      sudo reboot"
echo ""
