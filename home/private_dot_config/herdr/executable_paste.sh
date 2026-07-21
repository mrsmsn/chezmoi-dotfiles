#!/usr/bin/env bash
# prefix+p (keys.command) から呼ばれ、OS クリップボードをフォーカス中ペインへ送る。
# herdr 0.7.1 の [keys] にはペーストアクションが無いため CLI で代替する。
set -eu

bin="${HERDR_BIN_PATH:-herdr}"

if command -v pbpaste >/dev/null 2>&1; then
  text="$(pbpaste)"
elif command -v wl-paste >/dev/null 2>&1; then
  text="$(wl-paste --no-newline)"
elif command -v xclip >/dev/null 2>&1; then
  text="$(xclip -selection clipboard -o)"
else
  exit 0
fi
[ -n "$text" ] || exit 0

pane="$("$bin" pane current | jq -r '.result.pane.pane_id')"
exec "$bin" pane send-text "$pane" "$text"
