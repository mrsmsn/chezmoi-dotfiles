#!/usr/bin/env bash
# Stop hook: `just ci-fast` を完了ゲートとして実行し、失敗時は decision="block"
# で停止を差し戻して Claude に修正させる。stop_hook_active で無限ループ防止。

set -u
set -o pipefail

emit_block() {
  local reason="$1"
  jq -Rn --arg r "$reason" '{ decision: "block", reason: $r }'
}

emit_context() {
  local msg="$1"
  jq -Rn --arg msg "$msg" '{
        hookSpecificOutput: {
            hookEventName: "Stop",
            additionalContext: $msg
        }
    }'
}

input="$(cat)"
active="$(jq -r '.stop_hook_active // false' <<<"$input" 2>/dev/null || echo false)"
if [ "$active" = "true" ]; then
  exit 0
fi

project_dir="${CLAUDE_PROJECT_DIR:-$PWD}"
cd "$project_dir" || {
  emit_context "local-ci hook: failed to cd into project dir $project_dir"
  exit 0
}

if ! command -v just >/dev/null 2>&1; then
  emit_context "local-ci hook skipped: \`just\` not found on PATH. Install just to enable the completion gate."
  exit 0
fi
if ! command -v podman >/dev/null 2>&1; then
  emit_context "local-ci hook skipped: \`podman\` not found on PATH. Install podman to enable the completion gate."
  exit 0
fi

set +e
output="$(just ci-fast 2>&1)"
rc=$?
set -e

if [ "$rc" -eq 0 ]; then
  exit 0
fi

trimmed="$(printf '%s\n' "$output" | tail -40)"
reason=$'just ci-fast failed (exit '"$rc"$'):\n\n'"$trimmed"$'\n\nRun `just ci-fast` locally to reproduce and fix before completing.'
emit_block "$reason"
exit 0
