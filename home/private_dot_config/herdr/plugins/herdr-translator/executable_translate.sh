#!/usr/bin/env bash
# herdr-translator entry stage (plugin action).
# 翻訳対象を選択テキスト (プラグインコンテキスト) → OS クリップボードの順で
# 取得し、ファイル渡しでポップアップ (render.sh) を開く。herdr のコピーモード
# で y するとクリップボードに入るため、フォールバックだけでも一連の
# 「選択 → y → prefix+t」フローが成立する。
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=helpers.sh
source "$SCRIPT_DIR/helpers.sh"

# trim leading/trailing whitespace (incl. newlines).
trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

selection_from_context() {
  [ -n "${HERDR_PLUGIN_CONTEXT_JSON:-}" ] || return 1
  command -v jq >/dev/null 2>&1 || return 1
  printf '%s' "$HERDR_PLUGIN_CONTEXT_JSON" | jq -r '.selected_text // empty'
}

selection_from_clipboard() {
  if command -v pbpaste >/dev/null 2>&1; then
    pbpaste
  elif command -v wl-paste >/dev/null 2>&1; then
    wl-paste --no-newline
  elif command -v xclip >/dev/null 2>&1; then
    xclip -selection clipboard -o
  else
    return 1
  fi
}

main() {
  local text
  text="$(trim "$(selection_from_context || true)")"
  if [ -z "$text" ]; then
    text="$(trim "$(selection_from_clipboard || true)")"
  fi
  [ -n "$text" ] || exit 0

  # render.sh (別プロセスのポップアップ) へはファイルで受け渡す
  local dir
  dir="$(cache_dir)"
  mkdir -p -- "$dir"
  printf '%s' "$text" > "$dir/src.txt"

  exec "${HERDR_BIN_PATH:-herdr}" plugin pane open \
    --plugin mrsmsn.translator --entrypoint popup
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main
fi
