#!/bin/bash
# Run as osi inside the guest.
set -e

sudo xbps-install -y \
    make gcc zlib-devel bzip2-devel readline-devel sqlite-devel \
    openssl-devel tk-devel libffi-devel xz-devel liblzma-devel \
    ncurses-devel patch curl git

if [ ! -d "$HOME/.pyenv" ]; then
    git clone https://github.com/pyenv/pyenv.git ~/.pyenv
    git clone https://github.com/pyenv/pyenv-virtualenv.git ~/.pyenv/plugins/pyenv-virtualenv
fi

if [ ! -d "$HOME/.rbenv" ]; then
    git clone https://github.com/rbenv/rbenv.git ~/.rbenv
    git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
fi

grep -q 'pyenv' ~/.bashrc || cat >> ~/.bashrc << 'EOF'

export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"

export RBENV_ROOT="$HOME/.rbenv"
export PATH="$RBENV_ROOT/bin:$PATH"
eval "$(rbenv init -)"
EOF

echo "Done. Run: source ~/.bashrc"
echo "Then: pyenv install 3.12.3 && pyenv global 3.12.3"
echo "Then: rbenv install 3.3.0  && rbenv global 3.3.0"
