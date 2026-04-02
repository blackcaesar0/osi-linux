#!/bin/bash
# Run as the desktop user inside the guest.
# Deploys shell configs, editor settings, and workspace templates.
set -euo pipefail

BASE="$(cd "$(dirname "$0")/.." && pwd)"

step() { echo; echo "==> $*"; }

# ── Shell configs ─────────────────────────────────────────────────────────────
step "Deploying shell configs"
cp "$BASE/config/shell/bash_aliases" ~/.bash_aliases
cp "$BASE/config/vim/vimrc"          ~/.vimrc

grep -q '# OSI: bash_aliases' ~/.bashrc 2>/dev/null || cat >> ~/.bashrc << 'EOF'

# OSI: bash_aliases
if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi
EOF

# ── tmux config ───────────────────────────────────────────────────────────────
step "Deploying tmux config"
cp "$BASE/config/tmux/tmux.conf" ~/.tmux.conf

# ── Custom prompt — cyberpunk theme matching the desktop ──────────────────────
step "Setting up bash prompt"
grep -q 'OSI_PROMPT' ~/.bashrc 2>/dev/null || cat >> ~/.bashrc << 'PROMPTEOF'

# OSI prompt — cyan accent, shows IP of primary outbound interface
_osi_ip() {
    ip route get 1.1.1.1 2>/dev/null | awk '/src/{print $7; exit}'
}
OSI_PROMPT=1
PS1='\[\033[36;1m\]\u\[\033[0m\]@\[\033[35m\]\h\[\033[0m\] \[\033[34m\]\w\[\033[0m\]$( _ip=$(_osi_ip); [ -n "$_ip" ] && printf " \[\033[36m\][%s]\[\033[0m\]" "$_ip" ) \[\033[36;1m\]>\[\033[0m\] '
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
