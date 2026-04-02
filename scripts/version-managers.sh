#!/bin/bash
# Run as the desktop user (NOT root) inside the guest.
# Sets up pyenv, pipx with default Python versions. Uses system Ruby.
set -euo pipefail

step() { echo; echo "==> $*"; }

# Guard: do not run as root
if [ "$(id -u)" -eq 0 ]; then
    echo "ERROR: Run as your desktop user, not root."
    exit 1
fi

# ── Clean up leftover rbenv ───────────────────────────────────────────────────
if [ -d "$HOME/.rbenv" ]; then
    step "Removing leftover rbenv installation"
    rm -rf "$HOME/.rbenv"
    sed -i '/rbenv/d' ~/.bashrc 2>/dev/null || true
fi

# ── pyenv ─────────────────────────────────────────────────────────────────────
step "Setting up pyenv"
if [ ! -d "$HOME/.pyenv" ]; then
    git clone https://github.com/pyenv/pyenv.git ~/.pyenv
    git clone https://github.com/pyenv/pyenv-virtualenv.git ~/.pyenv/plugins/pyenv-virtualenv
fi

# Shell config — idempotent
grep -q 'pyenv init' ~/.bashrc 2>/dev/null || cat >> ~/.bashrc << 'EOF'

# pyenv
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"
EOF

# Load for this session
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

# Python versions — 3.12 as global default, keep older ones for tool compat
step "Installing Python versions (this takes several minutes per version)"
for ver in 3.9.19 3.10.14 3.11.9 3.12.3; do
    if pyenv versions --bare | grep -q "^${ver}$"; then
        echo "    Python $ver already installed"
    else
        echo "    Installing Python $ver..."
        pyenv install -s "$ver" || echo "    WARNING: Python $ver failed to build, skipping"
    fi
done
pyenv global 3.12.3

# pipx — install in user context
step "Setting up pipx"
python -m pip install --user --quiet --upgrade pip 2>/dev/null || pip install --user --quiet --upgrade pip
python -m pip install --user --quiet pipx 2>/dev/null || pip install --user --quiet pipx
export PATH="$HOME/.local/bin:$PATH"
pipx ensurepath 2>/dev/null || true

# Ruby — system Ruby from XBPS is used directly (already installed by base-setup.sh).
# rbenv is not used to avoid native extension build failures (psych, etc.).
step "Checking system Ruby"
if command -v ruby &>/dev/null; then
    echo "    Ruby: $(ruby --version 2>&1)"
else
    echo "    WARNING: Ruby not found — install with: sudo xbps-install -y ruby"
fi

echo ""
echo "==> Version managers ready."
echo "    Python : $(python --version 2>&1)"
echo "    Ruby   : $(ruby --version 2>&1 || echo 'not installed')"
echo "    pipx   : $(pipx --version 2>&1 || echo 'not installed')"
