#!/bin/bash
# GH Actions の lint job をローカル再現する (push 前に shellcheck 通すため)。
set -euo pipefail

bash -n install.sh

for f in home/dot_zshrc home/private_dot_config/zsh/*.zsh; do
    zsh -n "$f"
done

shellcheck install.sh ci/*.sh
