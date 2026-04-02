#!/bin/bash
# Run as osi inside the guest.
# Sets up pyenv, rbenv, pipx with default Python and Ruby versions.
set -euo pipefail

# pyenv
if [ ! -d "$HOME/.pyenv" ]; then
    git clone https://github.com/pyenv/pyenv.git ~/.pyenv
    git clone https://github.com/pyenv/pyenv-virtualenv.git ~/.pyenv/plugins/pyenv-virtualenv
fi

# rbenv
if [ ! -d "$HOME/.rbenv" ]; then
    git clone https://github.com/rbenv/rbenv.git ~/.rbenv
    git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
fi

# Shell config — idempotent
grep -q 'pyenv init' ~/.bashrc || cat >> ~/.bashrc << 'EOF'

# pyenv
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"

# rbenv
export RBENV_ROOT="$HOME/.rbenv"
export PATH="$RBENV_ROOT/bin:$PATH"
eval "$(rbenv init -)"
EOF

# Load for this session
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$HOME/.rbenv/bin:$PATH"
eval "$(pyenv init -)"
eval "$($HOME/.rbenv/bin/rbenv init -)"

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

# Ruby — for metasploit, evil-winrm, and similar tools
echo "==> Installing Ruby 3.2.4..."
rbenv install -s 3.2.4
rbenv global 3.2.4

echo "==> Version managers ready."
echo "    Python: $(python --version 2>&1)"
echo "    Ruby:   $(ruby --version 2>&1)"
echo "    pipx:   $(pipx --version 2>&1)"
