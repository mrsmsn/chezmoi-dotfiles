#!/usr/bin/env bash
# fzf-popup.sh が plugin pane open --env PICKER_DIR=... で開く overlay 側。
# 入力と引数をファイルから受け取って fzf を実行し、選択結果を out へ書く。
# out の存在が「完了」の合図なので、キャンセル時も空の out を必ず作る。
set -eu

dir="${PICKER_DIR:?}"

args=()
while IFS= read -r -d '' a; do args+=("$a"); done < "$dir/args"

fzf ${args+"${args[@]}"} < "$dir/in" > "$dir/out.tmp" || true
mv "$dir/out.tmp" "$dir/out"
