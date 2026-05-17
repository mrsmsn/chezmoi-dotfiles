#!/usr/bin/env bash
# INSTALL_SH_LIB=1 で source されると main を skip し、helper だけ定義する
# (bats からユニット呼び出しするための gate)。
set -euo pipefail

_decide_init_flags() {
    if [ "${1:-0}" = "1" ]; then
        return 0
    fi
    printf '%s\n' "--promptDefaults"
}

_probe_tty_available() {
    : < /dev/tty 2>/dev/null
}

_select_nix_ssl_cert_file() {
    if [ -n "${NIX_SSL_CERT_FILE:-}" ] && [ -f "${NIX_SSL_CERT_FILE}" ]; then
        printf '%s\n' "${NIX_SSL_CERT_FILE}"
        return 0
    fi
    local c
    for c in "$@"; do
        if [ -f "$c" ]; then
            printf '%s\n' "$c"
            return 0
        fi
    done
    return 1
}

main() {
    local repo_url="${1:-https://github.com/mrsmsn/chezmoi-dotfiles.git}"

    # Bats E2E は INSTALL_SH_DRY=1 で Nix install / chezmoi init / sudo を全部
    # 飛ばし、代わりに chezmoi を fakehome に対して直接叩く。
    if [ "${INSTALL_SH_DRY:-0}" = "1" ]; then
        echo "==> INSTALL_SH_DRY=1: skipping bootstrap (test mode)"
        return 0
    fi

    local os
    os="$(uname -s)"
    case "${os}" in
        Darwin|Linux) ;;
        *) echo "Unsupported OS: ${os}" >&2; exit 1 ;;
    esac

    if [[ "${os}" == "Darwin" ]] && ! xcode-select -p >/dev/null 2>&1; then
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

    # Nix 内蔵 curl は NIX_SSL_CERT_FILE で TLS を検証する。これが未 export か、
    # Linux 流の /etc/ssl/certs/ca-certificates.crt ハードコードを掴むビルドだと、
    # 新規 macOS で flake-registry.json 取得が "SSL CA cert (77)" で落ちる。
    local picked
    if picked=$(_select_nix_ssl_cert_file \
            /etc/ssl/cert.pem \
            /etc/ssl/certs/ca-certificates.crt \
            /nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt); then
        export NIX_SSL_CERT_FILE="${picked}"
    fi

    # nix-daemon は flake fetch を担当する一方で user-level
    # ~/.config/nix/nix.conf を読まないので、token は /etc/nix/nix.conf に書く。
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
            profile add nixpkgs#chezmoi
    fi

    echo "==> Initializing chezmoi from ${repo_url}"
    # chezmoi の promptStringOnce は /dev/tty を直接開くので、`curl | bash` でも
    # stdin が pipe なまま対話できる。真に TTY 無し (CI 等) のときだけ
    # --promptDefaults で default 値に fallback。
    local has_tty=0
    _probe_tty_available && has_tty=1
    local -a init_flags=()
    mapfile -t init_flags < <(_decide_init_flags "$has_tty")

    chezmoi init --apply "${init_flags[@]}" "${repo_url}"

    echo "==> Done. Run \`chezmoi status\` to inspect state."
}

if [ "${INSTALL_SH_LIB:-0}" != "1" ]; then
    main "$@"
fi
