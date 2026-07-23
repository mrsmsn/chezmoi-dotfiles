#!/usr/bin/env bash
# herdr 0.7.1 は外側ターミナルが CSI-u で送る ctrl+/ を内側 pty へ '/' と
# 再エンコードしてしまい、zsh の ^_ バインド (fzf-src) に届かない。
# ctrl+/ を herdr で直接拾い、レガシーエンコードの ^_ (0x1f) を
# フォーカスペインへ送り直す。
set -eu

bin="${HERDR_BIN_PATH:-herdr}"
pane="$("$bin" pane current | jq -r '.result.pane.pane_id')"
exec "$bin" pane send-keys "$pane" 'ctrl+_'
