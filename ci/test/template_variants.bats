#!/usr/bin/env bats
# .chezmoi.toml.tmpl の variant / machine 判定を darwin/linux/wsl 各ホストで
# シミュレートして検証。Linux ランナー上で darwin として render したとき、
# テンプレ内の `sysctl -n hw.model 2>/dev/null || true` が効いて machine が
# 空文字になることを確認する (`|| true` を外すと Linux 上で sysctl が non-zero
# で死ぬ)。

load 'helpers/common'

@test "darwin host: variant=darwin, machine empty when hw.model fallback fires" {
    run render_chezmoi_toml_tmpl darwin "irrelevant"
    [ "$status" -eq 0 ]
    [[ "$output" == *'variant = "darwin"'* ]]
    [[ "$output" == *'machine = ""'* ]]
}

@test "linux host (azure kernel): variant=linux, machine empty" {
    run render_chezmoi_toml_tmpl linux "6.5.0-1014-azure"
    [ "$status" -eq 0 ]
    [[ "$output" == *'variant = "linux"'* ]]
    [[ "$output" == *'is_wsl = false'* ]]
    [[ "$output" == *'machine = ""'* ]]
}

@test "wsl host (microsoft kernel): variant=wsl, is_wsl=true" {
    run render_chezmoi_toml_tmpl linux "5.15.0-microsoft-standard-WSL2"
    [ "$status" -eq 0 ]
    [[ "$output" == *'variant = "wsl"'* ]]
    [[ "$output" == *'is_wsl = true'* ]]
    [[ "$output" == *'machine = ""'* ]]
}

@test "android host (Pixel Linux Terminal): variant=android, is_wsl=false" {
    run render_chezmoi_toml_tmpl linux "6.12.60-android16-6-g54e1389bda83-ab14631638-4k"
    [ "$status" -eq 0 ]
    [[ "$output" == *'variant = "android"'* ]]
    [[ "$output" == *'is_wsl = false'* ]]
    [[ "$output" == *'machine = ""'* ]]
}

@test "darwin render on Linux host does not crash even though sysctl(8) is unavailable" {
    run render_chezmoi_toml_tmpl darwin "irrelevant"
    [ "$status" -eq 0 ]
}

@test "nixos host (os-release id=nixos): variant=nixos, is_wsl=false" {
    run render_chezmoi_toml_tmpl linux "6.12.0" "nixos"
    [ "$status" -eq 0 ]
    [[ "$output" == *'variant = "nixos"'* ]]
    [[ "$output" == *'is_wsl = false'* ]]
}

@test "linux host with unrelated os-release id (ubuntu): variant=linux" {
    run render_chezmoi_toml_tmpl linux "6.5.0-1014-azure" "ubuntu"
    [ "$status" -eq 0 ]
    [[ "$output" == *'variant = "linux"'* ]]
}

@test "wsl precedence over nixos: microsoft kernel wins even with os-release id=nixos" {
    run render_chezmoi_toml_tmpl linux "5.15.0-microsoft-standard-WSL2" "nixos"
    [ "$status" -eq 0 ]
    [[ "$output" == *'variant = "wsl"'* ]]
}
