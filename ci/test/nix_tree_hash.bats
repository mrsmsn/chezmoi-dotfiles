#!/usr/bin/env bats
# run_onchange_20-nix-activate.sh.tmpl の冒頭に
# `# nix-tree-hash: {{ output "git" ... "rev-parse" "HEAD:nix" }}` が埋まっている。
# chezmoi が「nix/ の tree hash が変わったら run_onchange を再実行する」契約を
# 成立させるための仕掛けで、ここが壊れると Nix 側の編集が黙って未反映になる。

load 'helpers/common'

ACTIVATE_TMPL="home/run_onchange_20-nix-activate.sh.tmpl"

render_activate() {
    local variant="$1"
    sed "s|\.variant|\"${variant}\"|g" \
        "${PROJECT_ROOT}/${ACTIVATE_TMPL}" \
        | chezmoi --source="${PROJECT_ROOT}/home" execute-template
}

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
    # objects 共有の独立 worktree で nix/ を編集 → HEAD:nix が変わることを assert。
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
    rendered=$(render_activate darwin)
    stripped=$(printf '%s\n' "$rendered" | sed '/^# nix-tree-hash:/d')
    [ -z "$(printf '%s\n' "$stripped" | extract_hash)" ]
}
