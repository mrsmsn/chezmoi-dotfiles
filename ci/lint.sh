#!/bin/bash
set -euo pipefail

# Mirrors the `lint` job in .github/workflows/ci.yml so that pushing is not
# required to catch syntax errors in install.sh, dot_zshrc, or the split
# modules under home/private_dot_config/zsh.

bash -n install.sh

for f in home/dot_zshrc home/private_dot_config/zsh/*.zsh; do
    zsh -n "$f"
done

shellcheck install.sh ci/*.sh
