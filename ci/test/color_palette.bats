#!/usr/bin/env bats
# starship / herdr の配色一元管理 (.chezmoidata/colors.toml) の lint + 回帰。
# - tmpl への hex 直書きを禁止し、palette (.colors.*) 参照を強制する
# - machine="" / mac-mini-m4 / 未知マシンの render 結果が期待配色になる
#
# .chezmoidata は source state の一部なので、stdin 渡しの render でも
# `--source "$PROJECT_ROOT/home"` が無いと .colors が未定義になる。

load 'helpers/common'

STARSHIP_TMPL="home/private_dot_config/starship.toml.tmpl"
HERDR_TMPL="home/private_dot_config/herdr/config.toml.tmpl"

teardown() {
    if [ -n "${TMPHOME:-}" ]; then
        rm -rf "$TMPHOME"
    fi
}

render_with_machine() {
    # Args: $1=machine, $2=tmpl (repo 相対パス)
    local cfg="$TMPHOME/chezmoi.toml"
    printf '[data]\n    variant = "darwin"\n    machine = "%s"\n' "$1" > "$cfg"
    chezmoi --config "$cfg" --source "$PROJECT_ROOT/home" execute-template \
        < "$PROJECT_ROOT/$2"
}

@test "lint: starship tmpl に hex 直書きなし" {
    run grep -nE '#[0-9a-fA-F]{3,8}' "$PROJECT_ROOT/$STARSHIP_TMPL"
    [ "$status" -ne 0 ]
}

@test "lint: herdr tmpl に hex 直書きなし" {
    run grep -nE '#[0-9a-fA-F]{3,8}' "$PROJECT_ROOT/$HERDR_TMPL"
    [ "$status" -ne 0 ]
}

@test "lint: 両 tmpl が .colors.palettes を参照している" {
    grep -q 'index .colors.palettes .machine' "$PROJECT_ROOT/$STARSHIP_TMPL"
    grep -q 'index .colors.palettes .machine' "$PROJECT_ROOT/$HERDR_TMPL"
}

@test "starship machine=\"\": 青系パレット" {
    TMPHOME=$(mktemp -d)
    output=$(render_with_machine "" "$STARSHIP_TMPL")
    [[ "$output" == *"#a3aed2"* ]]
    [[ "$output" == *"#769ff0"* ]]
    [[ "$output" == *"fg:#a0a9cb"* ]]
    [[ "$output" == *"fg:#090c0c"* ]]
    [[ "$output" != *"#00af87"* ]]
}

@test "starship machine=mac-mini-m4: 緑系パレット" {
    TMPHOME=$(mktemp -d)
    output=$(render_with_machine "mac-mini-m4" "$STARSHIP_TMPL")
    [[ "$output" == *"#00af87"* ]]
    [[ "$output" == *"#7fd1b9"* ]]
    [[ "$output" != *"#769ff0"* ]]
}

@test "herdr machine=\"\": accent は starship と別値の水色 (現状維持)" {
    TMPHOME=$(mktemp -d)
    output=$(render_with_machine "" "$HERDR_TMPL")
    [[ "$output" == *'accent = "#7fc8ff"'* ]]
}

@test "herdr machine=mac-mini-m4: accent は starship と同じ緑" {
    TMPHOME=$(mktemp -d)
    output=$(render_with_machine "mac-mini-m4" "$HERDR_TMPL")
    [[ "$output" == *'accent = "#00af87"'* ]]
}

@test "未知マシンは default パレットに落ちる" {
    TMPHOME=$(mktemp -d)
    output=$(render_with_machine "unknown-host" "$STARSHIP_TMPL")
    [[ "$output" == *"#769ff0"* ]]
    [[ "$output" != *"#00af87"* ]]
}
