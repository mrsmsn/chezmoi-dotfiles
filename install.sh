#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${1:-https://github.com/mrsmsn/chezmoi-dotfiles.git}"

OS="$(uname -s)"
case "${OS}" in
    Darwin|Linux) ;;
    *) echo "Unsupported OS: ${OS}" >&2; exit 1 ;;
esac

if ! command -v nix >/dev/null 2>&1; then
    echo "==> Installing Nix (Determinate Systems installer)"
    curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
        | sh -s -- install --no-confirm
fi

if [[ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
    # shellcheck disable=SC1091
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
elif [[ -e "${HOME}/.nix-profile/etc/profile.d/nix.sh" ]]; then
    # shellcheck disable=SC1091
    . "${HOME}/.nix-profile/etc/profile.d/nix.sh"
fi

if ! command -v chezmoi >/dev/null 2>&1; then
    echo "==> Installing chezmoi via Nix"
    nix --extra-experimental-features 'nix-command flakes' \
        profile install nixpkgs#chezmoi
fi

echo "==> Initializing chezmoi from ${REPO_URL}"
chezmoi init --apply "${REPO_URL}"

echo "==> Done. Run \`chezmoi status\` to inspect state."
