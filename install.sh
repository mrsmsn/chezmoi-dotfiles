#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${1:-https://github.com/mrsmsn/chezmoi-dotfiles.git}"

OS="$(uname -s)"
case "${OS}" in
    Darwin|Linux) ;;
    *) echo "Unsupported OS: ${OS}" >&2; exit 1 ;;
esac

if [[ "${OS}" == "Darwin" ]] && ! xcode-select -p >/dev/null 2>&1; then
    echo "==> Installing Xcode Command Line Tools"
    echo "    GUI ダイアログから 'インストール' を選択して完了を待ってください"
    xcode-select --install || true
    until xcode-select -p >/dev/null 2>&1; do sleep 5; done
fi

if ! command -v nix >/dev/null 2>&1; then
    echo "==> Installing Nix (NixOS official installer)"
    curl --proto '=https' --tlsv1.2 -sSf -L https://artifacts.nixos.org/nix-installer \
        | sh -s -- install --no-confirm --enable-flakes
fi

if [[ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
    # shellcheck disable=SC1091
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
elif [[ -e "${HOME}/.nix-profile/etc/profile.d/nix.sh" ]]; then
    # shellcheck disable=SC1091
    . "${HOME}/.nix-profile/etc/profile.d/nix.sh"
fi

# Nix の内蔵 curl は NIX_SSL_CERT_FILE が指す CA バンドルで TLS を検証する。
# nix-daemon.sh がこれを export しないビルドや、Linux 流の
# /etc/ssl/certs/ca-certificates.crt をハードコードで参照する構成だと、
# 新規インストール直後の macOS で flake-registry.json の取得が
# "Problem with the SSL CA cert (path? access rights?) (77)" で落ちる。
# 既存値が無効なら有効そうな候補に差し替える。
if [[ -z "${NIX_SSL_CERT_FILE:-}" || ! -f "${NIX_SSL_CERT_FILE}" ]]; then
    for candidate in \
        /etc/ssl/cert.pem \
        /etc/ssl/certs/ca-certificates.crt \
        /nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt; do
        if [[ -f "${candidate}" ]]; then
            export NIX_SSL_CERT_FILE="${candidate}"
            break
        fi
    done
fi

# When a GITHUB_TOKEN is provided (CI), write it to /etc/nix/nix.conf so
# the nix-daemon — which performs flake fetches and doesn't read user-
# level ~/.config/nix/nix.conf — authenticates against the GitHub API.
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    if ! sudo grep -q '^access-tokens' /etc/nix/nix.conf 2>/dev/null; then
        echo "==> Adding GitHub access-tokens to /etc/nix/nix.conf"
        echo "access-tokens = github.com=${GITHUB_TOKEN}" \
            | sudo tee -a /etc/nix/nix.conf >/dev/null
    fi
fi

if ! command -v chezmoi >/dev/null 2>&1; then
    echo "==> Installing chezmoi via Nix"
    nix --extra-experimental-features 'nix-command flakes' \
        profile install nixpkgs#chezmoi
fi

echo "==> Initializing chezmoi from ${REPO_URL}"
# 非 TTY 環境 (CI 等) では promptStringOnce が default に fallback せず TTY
# を開こうとして失敗するので、--promptDefaults を付けて default を使わせる。
# 対話実行ではそのまま prompt させる。
INIT_FLAGS=()
if [[ ! -t 0 || ! -t 1 ]]; then
    INIT_FLAGS+=(--promptDefaults)
fi
chezmoi init --apply "${INIT_FLAGS[@]}" "${REPO_URL}"

echo "==> Done. Run \`chezmoi status\` to inspect state."
