#!/usr/bin/env bats
# install.sh の helper をユニットテスト。`INSTALL_SH_LIB=1` で source すると
# main を skip するので副作用なしにロジックだけ叩ける。

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
    run _probe_tty_available
    [ "$status" -ne 0 ]
}

@test "_is_nixos: returns success when given an existing path" {
    tmp=$(mktemp -d)
    touch "$tmp/NIXOS"
    run _is_nixos "$tmp/NIXOS"
    rm -rf "$tmp"
    [ "$status" -eq 0 ]
}

@test "_is_nixos: returns failure when given a nonexistent path" {
    run _is_nixos "/nonexistent/NIXOS-marker"
    [ "$status" -ne 0 ]
}
