#!/usr/bin/env bash
# Stop hook: runs the full local CI (`just ci`) as a completion gate.
# Blocks the stop with decision="block" on failure so Claude resumes and
# fixes the regression. Honors stop_hook_active to avoid infinite loops.

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
output="$(just ci 2>&1)"
rc=$?
set -e

if [ "$rc" -eq 0 ]; then
    exit 0
fi

trimmed="$(printf '%s\n' "$output" | tail -40)"
reason=$'just ci failed (exit '"$rc"$'):\n\n'"$trimmed"$'\n\nRun `just ci` locally to reproduce and fix before completing.'
emit_block "$reason"
exit 0
