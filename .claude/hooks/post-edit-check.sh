#!/usr/bin/env bash
# PostToolUse hook: 編集ファイルだけに per-file の bash/zsh syntax + shellcheck
# を即時走らせて、違反を additionalContext で同一ループ内に返す (フル検証は
# 手動の `just ci-fast`)。

set -u
set -o pipefail

emit_context() {
    local msg="$1"
    jq -Rn --arg msg "$msg" '{
        hookSpecificOutput: {
            hookEventName: "PostToolUse",
            additionalContext: $msg
        }
    }'
}

input="$(cat)"
file="$(jq -r '.tool_input.file_path // .tool_input.path // empty' <<<"$input" 2>/dev/null || true)"

[ -z "$file" ] && exit 0
[ ! -f "$file" ] && exit 0

project_dir="${CLAUDE_PROJECT_DIR:-$PWD}"
case "$file" in
    "$project_dir"/*) ;;
    *) exit 0 ;;
esac

rel="${file#"$project_dir"/}"
diag=""
status=0

run_bash_syntax() {
    local out
    if ! out="$(bash -n "$file" 2>&1)"; then
        diag+="bash -n: ${rel}\n${out}\n"
        status=1
    fi
}

run_shellcheck() {
    if ! command -v shellcheck >/dev/null 2>&1; then
        return 0
    fi
    local out
    if ! out="$(shellcheck "$file" 2>&1)"; then
        diag+="shellcheck: ${rel}\n${out}\n"
        status=1
    fi
}

run_zsh_syntax() {
    if ! command -v zsh >/dev/null 2>&1; then
        return 0
    fi
    local out
    if ! out="$(zsh -n "$file" 2>&1)"; then
        diag+="zsh -n: ${rel}\n${out}\n"
        status=1
    fi
}

case "$rel" in
    *.tmpl) exit 0 ;;
    *.nix) exit 0 ;;
esac

case "$rel" in
    install.sh|ci/*.sh|*.sh)
        run_bash_syntax
        run_shellcheck
        ;;
    home/dot_zshrc|home/private_dot_config/zsh/*.zsh)
        run_zsh_syntax
        ;;
    *)
        exit 0
        ;;
esac

if [ "$status" -ne 0 ]; then
    trimmed="$(printf '%b' "$diag" | head -40)"
    emit_context "$trimmed"
fi

exit 0
