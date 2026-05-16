#!/usr/bin/env bats
#
# install.sh の内部関数ユニットテスト。
# `INSTALL_SH_LIB=1` でファイルを source すると main は走らず、ヘルパー関数
# だけが定義されるので、副作用なくロジックを検証できる。
#
# 守るべき性質:
#   - TTY 判定: /dev/tty が開けない環境では `--promptDefaults` が付く
#     (PR #37 で fix した「curl | bash で user.name 空になる」事故の再発防止)
#   - CA cert 選択: valid な NIX_SSL_CERT_FILE は尊重、無効/未設定なら
#     候補から最初に存在するパスを選ぶ

load 'helpers/common'

setup() {
    # shellcheck disable=SC1091
    INSTALL_SH_LIB=1 source "${PROJECT_ROOT}/install.sh"
}

@test "_decide_init_flags: no TTY emits --promptDefaults" {
    run _decide_init_flags 0
    [ "$status" -eq 0 ]
    [ "$output" = "--promptDefaults" ]
}

@test "_decide_init_flags: TTY available emits nothing" {
    run _decide_init_flags 1
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "_select_nix_ssl_cert_file: keeps valid NIX_SSL_CERT_FILE" {
    tmp=$(mktemp -d)
    touch "$tmp/cert.pem"
    NIX_SSL_CERT_FILE="$tmp/cert.pem" \
        run _select_nix_ssl_cert_file /tmp/missing1 /tmp/missing2
    rm -rf "$tmp"
    [ "$status" -eq 0 ]
    # tmp is interpolated before we rm so $output should still reflect it
    [[ "$output" == */cert.pem ]]
}

@test "_select_nix_ssl_cert_file: ignores invalid NIX_SSL_CERT_FILE, walks candidates" {
    tmp=$(mktemp -d)
    touch "$tmp/fallback"
    NIX_SSL_CERT_FILE="/nonexistent/foo" \
        run _select_nix_ssl_cert_file "$tmp/fallback"
    [ "$status" -eq 0 ]
    [ "$output" = "$tmp/fallback" ]
    rm -rf "$tmp"
}

@test "_select_nix_ssl_cert_file: picks the first existing candidate" {
    tmp=$(mktemp -d)
    touch "$tmp/a"
    touch "$tmp/b"
    NIX_SSL_CERT_FILE="" \
        run _select_nix_ssl_cert_file /tmp/missing "$tmp/a" "$tmp/b"
    [ "$status" -eq 0 ]
    [ "$output" = "$tmp/a" ]
    rm -rf "$tmp"
}

@test "_select_nix_ssl_cert_file: no candidates → rc=1 with empty output" {
    NIX_SSL_CERT_FILE="" \
        run _select_nix_ssl_cert_file /tmp/missing1 /tmp/missing2
    [ "$status" -ne 0 ]
    [ -z "$output" ]
}

@test "_probe_tty_available inside non-tty bats: returns 1" {
    # Podman/CI 環境で bats を走らせる場合、controlling tty が無いので
    # /dev/tty を読めない → rc=1。実機 (macOS の対話シェル) でも `< /dev/null`
    # 経由 bats なら同様に rc=1 になる。
    run _probe_tty_available
    [ "$status" -ne 0 ]
}
