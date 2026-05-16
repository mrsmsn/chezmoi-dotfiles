#!/usr/bin/env bats
#
# .claude/hooks/local-ci.sh は Claude Code の Stop hook として動作し、
# `just ci-fast` の結果次第で Claude を block / 解放する。Hook 自身の
# 出力 JSON 形式や skip 条件が壊れると CI ゲートが silently 抜けるか、
# 逆に常に block して開発を止めてしまう。
#
# 守るべき性質:
#   1. stop_hook_active=true → exit 0、stdout 空 (無限ループ防止)
#   2. just が PATH に無い → exit 0、context メッセージで skip 表示
#   3. podman が PATH に無い → 同上 (個別メッセージ)
#   4. just (= ci-fast) が成功 → exit 0、stdout 空
#   5. just (= ci-fast) が失敗 → exit 0 だが stdout に decision="block" JSON

load 'helpers/common'
load 'helpers/shim'

HOOK="$PROJECT_ROOT/.claude/hooks/local-ci.sh"

# Each test creates a fresh shim_dir; teardown wipes it.
# We deliberately do NOT include /usr/bin or /bin in PATH because GH Actions'
# ubuntu-latest pre-installs podman at /usr/bin/podman, which would let
# `command -v podman` succeed even when we explicitly want it to fail.
# Instead we symlink only the binaries the hook itself depends on into the
# shim dir, then restrict PATH to that dir only.
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
    # SHIM_DIR is empty → command -v just fails → skip path taken.
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
