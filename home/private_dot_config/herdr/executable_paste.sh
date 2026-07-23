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
# bracketed paste で括る: 素の send-text だと改行がそのまま実行になる。
# zsh (ZLE) はデフォルトで bracketed paste 有効なので、複数行でも
# 編集バッファへの挿入に留まる。
exec "$bin" pane send-text "$pane" $'\e[200~'"$text"$'\e[201~'
