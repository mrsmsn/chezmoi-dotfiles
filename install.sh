#!/usr/bin/env bash
set -euo pipefail

# Library guard: when sourced from bats (INSTALL_SH_LIB=1) we only define
# functions and skip `main`, so individual helpers can be unit-tested
# without re-running the full bootstrap (which curl|installs Nix etc.).

# Decide chezmoi init flags based on whether a /dev/tty was probed available.
# Args:
#   $1 = "1" if /dev/tty can be opened (interactive), anything else otherwise.
# Stdout: one flag per line (empty when interactive).
_decide_init_flags() {
    if [ "${1:-0}" = "1" ]; then
        return 0
    fi
    printf '%s\n' "--promptDefaults"
}

# Probe whether /dev/tty is openable from the current process.
# Returns 0 if usable, 1 otherwise. Side-effect free.
_probe_tty_available() {
    : < /dev/tty 2>/dev/null
}

# Pick the right CA bundle for the Nix-bundled curl.
# Args: positional candidate paths, tried in order.
# Stdout: the first path that exists (NIX_SSL_CERT_FILE wins if valid).
# Returns 1 if nothing was selectable.
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

    # Bats E2E sets INSTALL_SH_DRY=1 to skip all bootstrap side-effects
    # (Nix install / chezmoi init / sudo writes). The E2E test instead
    # drives chezmoi directly against a fakehome, which is far cheaper
    # than a full Nix install and still exercises template rendering.
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

    # Nix の内蔵 curl は NIX_SSL_CERT_FILE が指す CA バンドルで TLS を検証する。
    # nix-daemon.sh がこれを export しないビルドや、Linux 流の
    # /etc/ssl/certs/ca-certificates.crt をハードコードで参照する構成だと、
    # 新規インストール直後の macOS で flake-registry.json の取得が
    # "Problem with the SSL CA cert (path? access rights?) (77)" で落ちる。
    # 既存値が無効なら有効そうな候補に差し替える。
    local picked
    if picked=$(_select_nix_ssl_cert_file \
            /etc/ssl/cert.pem \
            /etc/ssl/certs/ca-certificates.crt \
            /nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt); then
        export NIX_SSL_CERT_FILE="${picked}"
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
            profile add nixpkgs#chezmoi
    fi

    echo "==> Initializing chezmoi from ${repo_url}"
    # chezmoi の promptStringOnce は prompt 時 /dev/tty を直接開く。`curl | bash`
    # で実行された場合 stdin は pipe (非 TTY) だが /dev/tty は使えるので普通に
    # 対話できる。真に TTY が無い環境 (CI 等) でのみ --promptDefaults で defaults
    # にフォールバックする。
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
