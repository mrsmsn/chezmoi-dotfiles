#!/usr/bin/env bats
# .claude/hooks/local-ci.sh は Claude Code Stop hook として呼ばれ、
# `just ci-fast` の結果次第で Claude を block / 解放する。出力 JSON 形式が壊れる
# と、CI gate が silently 抜けるか逆に常に block して開発が止まる。

load 'helpers/common'
load 'helpers/shim'

HOOK="$PROJECT_ROOT/.claude/hooks/local-ci.sh"

# GH Actions ubuntu-latest は /usr/bin/podman を pre-install しているので、
# 「podman 無し」を試すには PATH から /usr/bin /bin を外す必要がある。hook 自身が
# 必要とするバイナリだけを shim_dir に symlink して PATH をそこだけに絞る。
setup() {
    SHIM_DIR=$(make_shim_dir)
    local bin src
    for bin in jq cat bash tail; do
        src=$(PATH=/usr/bin:/bin command -v "$bin")
        ln -s "$src" "$SHIM_DIR/$bin"
    done
}

teardown() {
    if [ -n "${SHIM_DIR:-}" ]; then
        rm -rf "$SHIM_DIR"
    fi
}

run_hook() {
    local stdin="$1"
    run env -i HOME="$HOME" \
        PATH="$SHIM_DIR" \
        CLAUDE_PROJECT_DIR="$PROJECT_ROOT" \
        bash "$HOOK" <<<"$stdin"
}

@test "stop_hook_active=true: exits 0 with empty stdout (loop guard)" {
    run_hook '{"stop_hook_active":true}'
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "just missing: exits 0 and emits Stop hookSpecificOutput context" {
    run_hook '{"stop_hook_active":false}'
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    echo "$output" | jq -e '.hookSpecificOutput.hookEventName == "Stop"'
    echo "$output" | jq -e '.hookSpecificOutput.additionalContext | test("just")'
}

@test "podman missing (just present): exits 0 with podman skip context" {
    shim_cmd "$SHIM_DIR" just 0 ""
    run_hook '{"stop_hook_active":false}'
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    echo "$output" | jq -e '.hookSpecificOutput.additionalContext | test("podman")'
}

@test "just ci-fast green: exits 0 with empty stdout" {
    shim_cmd "$SHIM_DIR" just 0 "all green"
    shim_cmd "$SHIM_DIR" podman 0 ""
    run_hook '{"stop_hook_active":false}'
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "just ci-fast red: exits 0 with decision=block JSON carrying tail of output" {
    shim_cmd "$SHIM_DIR" just 1 "boom: ci failed somewhere"
    shim_cmd "$SHIM_DIR" podman 0 ""
    run_hook '{"stop_hook_active":false}'
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    echo "$output" | jq -e '.decision == "block"'
    echo "$output" | jq -e '.reason | test("just ci-fast failed \\(exit 1\\)")'
    echo "$output" | jq -e '.reason | test("boom: ci failed somewhere")'
}
