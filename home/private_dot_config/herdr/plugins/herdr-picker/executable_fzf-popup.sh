#!/usr/bin/env bash
# fzf を herdr の overlay ペインで前面表示する fzf-tmux -p 相当。
# 標準入力と引数をファイル渡しで fzf-pane.sh へ引き継ぎ、選択結果を
# 標準出力へ返す。overlay は別プロセスのため直接のパイプが張れない。
# herdr 外や RPC 失敗時は素の fzf にフォールバックする。
set -eu

if [ -z "${HERDR_PANE_ID:-}" ]; then
  exec fzf "$@"
fi

dir="$(mktemp -d "${TMPDIR:-/tmp}/herdr-picker.XXXXXX")"
trap 'rm -rf -- "$dir"' EXIT

if [ -t 0 ]; then
  : > "$dir/in"
else
  cat > "$dir/in"
fi
if [ "$#" -gt 0 ]; then
  printf '%s\0' "$@" > "$dir/args"
else
  : > "$dir/args"
fi

if ! "${HERDR_BIN_PATH:-herdr}" plugin pane open \
      --plugin mrsmsn.picker --entrypoint fzf \
      --cwd "$PWD" --env "PICKER_DIR=$dir" >/dev/null 2>&1; then
  exec fzf "$@" < "$dir/in"
fi

# out の出現 = 選択完了 (fzf-pane.sh がキャンセル時も必ず作る)。最長 5 分。
i=0
while [ ! -e "$dir/out" ] && [ "$i" -lt 3000 ]; do
  sleep 0.1
  i=$((i + 1))
done
cat "$dir/out" 2>/dev/null || true
