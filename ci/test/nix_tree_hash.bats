#!/usr/bin/env bats
#
# home/run_onchange_20-nix-activate.sh.tmpl の冒頭コメントに
# `# nix-tree-hash: {{ output "git" ... "rev-parse" "HEAD:nix" }}` が
# 埋め込まれている。これは chezmoi が「nix/ ディレクトリの tree hash が
# 変わったら run_onchange を再実行する」契約を成立させるための仕掛けで、
# ここが壊れると Nix 側の編集が黙って未反映になる。
#
# 守るべき性質:
#   1. 任意の variant で render 結果のどこかに `# nix-tree-hash: <40 hex>`
#   2. その hash が `git -C <root> rev-parse HEAD:nix` と一致する
#   3. nix/ 配下に変更を加えると git tree hash が確かに変わる
#      (= chezmoi が onchange 再実行をトリガできる)

load 'helpers/common'

ACTIVATE_TMPL="home/run_onchange_20-nix-activate.sh.tmpl"

render_activate() {
    local variant="$1"
    sed "s|\.variant|\"${variant}\"|g" \
        "${PROJECT_ROOT}/${ACTIVATE_TMPL}" \
        | chezmoi --source="${PROJECT_ROOT}/home" execute-template
}

# Pull the 40-char hex out of the first `# nix-tree-hash:` line in stdin.
extract_hash() {
    grep -m1 -oE '^# nix-tree-hash: [0-9a-f]{40}$' | awk '{print $3}'
}

@test "darwin variant: rendered output carries a nix-tree-hash hex line" {
    rendered=$(render_activate darwin)
    [[ "$rendered" =~ \#\ nix-tree-hash:\ [0-9a-f]{40} ]]
}

@test "linux variant: embedded hash matches HEAD:nix" {
    rendered=$(render_activate linux)
    hash=$(printf '%s\n' "$rendered" | extract_hash)
    expected=$(git -C "$PROJECT_ROOT" rev-parse HEAD:nix)
    [ -n "$hash" ]
    [ "$hash" = "$expected" ]
}

@test "wsl variant: embedded hash matches HEAD:nix" {
    rendered=$(render_activate wsl)
    hash=$(printf '%s\n' "$rendered" | extract_hash)
    expected=$(git -C "$PROJECT_ROOT" rev-parse HEAD:nix)
    [ -n "$hash" ]
    [ "$hash" = "$expected" ]
}

@test "modifying nix/ changes the tree hash chezmoi watches" {
    # `git clone --shared` で objects を共有しつつ独立した worktree を作り、
    # nix/ にダミー編集 → commit → HEAD:nix が変わる、ことを assert。
    # chezmoi が onchange 再実行をトリガできる土台の担保。
    tmp=$(mktemp -d)
    git clone --shared --no-hardlinks --quiet "$PROJECT_ROOT" "$tmp/clone"
    pre=$(git -C "$tmp/clone" rev-parse HEAD:nix)
    echo "# regression marker $(date +%s%N)" >> "$tmp/clone/nix/flake.nix"
    GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t \
    GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t \
        git -C "$tmp/clone" -c commit.gpgsign=false \
            commit --quiet -a -m "regression test"
    post=$(git -C "$tmp/clone" rev-parse HEAD:nix)
    rm -rf "$tmp"
    [ "$pre" != "$post" ]
}

@test "canary: extract_hash returns empty for output with no marker line" {
    # 抽出ロジックそのものが「無いものを偽陽性で拾わない」ことの担保。
    # render 結果から nix-tree-hash 行だけを潰した文字列を流す。
    rendered=$(render_activate darwin)
    stripped=$(printf '%s\n' "$rendered" | sed '/^# nix-tree-hash:/d')
    [ -z "$(printf '%s\n' "$stripped" | extract_hash)" ]
}
