#!/bin/bash
# Run as osi inside the guest.
# Sets up pyenv, rbenv, pipx with default Python and Ruby versions.
set -euo pipefail

# pyenv
if [ ! -d "$HOME/.pyenv" ]; then
    git clone https://github.com/pyenv/pyenv.git ~/.pyenv
    git clone https://github.com/pyenv/pyenv-virtualenv.git ~/.pyenv/plugins/pyenv-virtualenv
fi

# Shell config — idempotent
grep -q 'pyenv init' ~/.bashrc || cat >> ~/.bashrc << 'EOF'

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
echo "==> Installing Python versions (this takes several minutes per version)..."
pyenv install -s 3.9.19
pyenv install -s 3.10.14
pyenv install -s 3.11.9
pyenv install -s 3.12.3
pyenv global 3.12.3

# pipx — uses the global Python
pip install --quiet --upgrade pip
pip install --quiet pipx
pipx ensurepath

# Ruby — system Ruby from XBPS is used directly (already installed by base-setup.sh).
# rbenv is not used for Ruby to avoid build issues with native extensions like psych.
# Tools like metasploit and evil-winrm work fine with system Ruby.
echo "==> Using system Ruby: $(ruby --version 2>&1)"

echo "==> Version managers ready."
echo "    Python : $(python --version 2>&1)"
echo "    Ruby   : $(ruby --version 2>&1)"
echo "    pipx   : $(pipx --version 2>&1)"
