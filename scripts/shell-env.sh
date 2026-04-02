#!/bin/bash
# Run as osi inside the guest.
# Deploys shell configs, editor settings, and workspace templates.
set -euo pipefail

BASE="$HOME/osi-setup"

step() { echo; echo "==> $*"; }

# ── Shell configs ─────────────────────────────────────────────────────────────
step "Deploying shell configs"
cp "$BASE/config/shell/bash_aliases" ~/.bash_aliases
cp "$BASE/config/vim/vimrc"          ~/.vimrc

grep -q '\.bash_aliases' ~/.bashrc || cat >> ~/.bashrc << 'EOF'

# Aliases
if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi
EOF

# ── tmux config ───────────────────────────────────────────────────────────────
step "Deploying tmux config"
cp "$BASE/config/tmux/tmux.conf" ~/.tmux.conf

# ── Custom prompt ─────────────────────────────────────────────────────────────
step "Setting up bash prompt"
grep -q 'OSI_PROMPT' ~/.bashrc || cat >> ~/.bashrc << 'PROMPTEOF'

# OSI prompt — shows IP of primary outbound interface when available
_osi_ip() {
    ip route get 1.1.1.1 2>/dev/null | awk '/src/{print $7; exit}'
}
OSI_PROMPT=1
PS1='\[\033[01;31m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]$( _ip=$(_osi_ip); [ -n "$_ip" ] && printf " [%s]" "$_ip" )\$ '
PROMPTEOF

# ── Workspace README stubs ────────────────────────────────────────────────────
step "Creating workspace README stubs"
for dir in recon exploitation post-exploitation web network forensics; do
    mkdir -p ~/tools/"$dir"
    target=~/tools/"$dir"/README.md
    if [ ! -f "$target" ]; then
        printf '# %s\n\nDrop tools, scripts, and notes here.\n' "$dir" > "$target"
    fi
done

echo ""
echo "==> Shell environment ready. Reload with: source ~/.bashrc"
