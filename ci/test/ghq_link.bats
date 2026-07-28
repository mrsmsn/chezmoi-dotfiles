#!/usr/bin/env bats
# run_onchange_35-link-ghq-src.sh.tmpl の契約。
#
# chezmoi の source dir は ghq root の外に固定されるので、dotfiles 自身が
# `ghq list` に出ない。ghq は root 配下の symlink を repo として辿るため、
# 実体を動かさずリンクだけで list に載せる。リンク名は remote URL から ghq の
# パス規約 (<root>/<host>/<owner>/<repo>) で組み、後から `ghq get` しても
# 同じパスに落ちて二重管理にならないことを保証する。

load 'helpers/common'

TMPL="home/run_onchange_35-link-ghq-src.sh.tmpl"

# Args: $1=path, $2=ghq_root
write_cfg() {
    local path="$1" root="$2"
    cat > "$path" <<EOF
[data]

[data.ghq]
    root = "${root}"
EOF
}

# レンダリング結果を返す。source dir は fake repo を指す。
render_link() {
    chezmoi --config "$CFG" --source "$SRC" execute-template < "${PROJECT_ROOT}/${TMPL}"
}

# レンダリングして実行する。
run_link() {
    render_link > "$TMPDIR_FOR_TEST/link.sh"
    bash "$TMPDIR_FOR_TEST/link.sh"
}

# Args: $1=remote url ("" なら origin を設定しない)
init_fake_source() {
    local url="$1"
    git -C "$REPO" init -q
    if [ -n "$url" ]; then
        git -C "$REPO" remote add origin "$url"
    fi
}

setup() {
    TMPDIR_FOR_TEST=$(mktemp -d)
    CFG="$TMPDIR_FOR_TEST/chezmoi.toml"
    # `.chezmoiroot = home` により sourceDir は repo ルートではなく その下の
    # home/ を指す。ghq が repo と認識するのは .git を持つ REPO 側なので、
    # 実環境と同じ入れ子で検証する。
    REPO="$TMPDIR_FOR_TEST/repo"
    SRC="$REPO/home"
    ROOT="$TMPDIR_FOR_TEST/ghqroot"
    mkdir -p "$SRC" "$ROOT"
    write_cfg "$CFG" "$ROOT"
}

teardown() {
    if [ -n "${TMPDIR_FOR_TEST:-}" ]; then
        rm -rf "$TMPDIR_FOR_TEST"
    fi
}

@test "https remote → <root>/<host>/<owner>/<repo> が repo ルートを指す symlink になる" {
    # sourceDir (= home/) ではなく .git を持つ repo ルートを指すこと。home/ を
    # 指すと ghq が repo と認識せず list に出ない。
    init_fake_source "https://github.com/mrsmsn/chezmoi-dotfiles.git"
    run_link
    link="$ROOT/github.com/mrsmsn/chezmoi-dotfiles"
    [ -L "$link" ]
    [ "$(readlink "$link")" = "$REPO" ]
    [ -d "$link/.git" ]
}

@test "scp 形式の remote でも同じパスに落ちる" {
    init_fake_source "git@github.com:mrsmsn/chezmoi-dotfiles.git"
    run_link
    [ -L "$ROOT/github.com/mrsmsn/chezmoi-dotfiles" ]
}

@test ".git サフィックスなしの remote でも同じパスに落ちる" {
    init_fake_source "https://github.com/mrsmsn/chezmoi-dotfiles"
    run_link
    [ -L "$ROOT/github.com/mrsmsn/chezmoi-dotfiles" ]
}

@test "github.com 以外の host でも host 名でディレクトリが分かれる" {
    init_fake_source "git@gitlab.com:mrsmsn/dots.git"
    run_link
    [ -L "$ROOT/gitlab.com/mrsmsn/dots" ]
}

@test "冪等: 2 回実行してもリンクは 1 本のまま" {
    init_fake_source "https://github.com/mrsmsn/chezmoi-dotfiles.git"
    run_link
    run_link
    link="$ROOT/github.com/mrsmsn/chezmoi-dotfiles"
    [ -L "$link" ]
    [ "$(readlink "$link")" = "$REPO" ]
    # ln -sfn がリンク先ディレクトリの中に入れ子リンクを作っていないこと。
    [ ! -e "$link/chezmoi-dotfiles" ]
}

@test "ghq.root 空 → ln も mkdir も出力しない" {
    init_fake_source "https://github.com/mrsmsn/chezmoi-dotfiles.git"
    write_cfg "$CFG" ""
    rendered=$(render_link)
    [[ "$rendered" != *'ln -sfn'* ]]
    [[ "$rendered" != *'mkdir -p'* ]]
}

@test "origin 未設定 → apply を止めずに skip する" {
    init_fake_source ""
    run_link
    [ "$(find "$ROOT" -mindepth 1 | wc -l)" -eq 0 ]
}

@test "source dir が git work tree でない → apply を止めずに skip する" {
    # tarball 展開など git 管理下でない source tree。
    run_link
    [ "$(find "$ROOT" -mindepth 1 | wc -l)" -eq 0 ]
}

@test "リンク先が実ディレクトリとして既に存在 → 上書きも入れ子リンクもせず skip" {
    # ghq get で実体を clone 済みのケース。ln -sfn はディレクトリの中に
    # リンクを作ってしまうので、その事故を踏まないこと。
    init_fake_source "https://github.com/mrsmsn/chezmoi-dotfiles.git"
    existing="$ROOT/github.com/mrsmsn/chezmoi-dotfiles"
    mkdir -p "$existing"
    touch "$existing/canary"
    run_link
    [ ! -L "$existing" ]
    [ -f "$existing/canary" ]
    [ ! -e "$existing/chezmoi-dotfiles" ]
}

@test "別ターゲットを指す既存 symlink は張り替える" {
    init_fake_source "https://github.com/mrsmsn/chezmoi-dotfiles.git"
    stale="$TMPDIR_FOR_TEST/stale"
    mkdir -p "$stale" "$ROOT/github.com/mrsmsn"
    ln -s "$stale" "$ROOT/github.com/mrsmsn/chezmoi-dotfiles"
    run_link
    [ "$(readlink "$ROOT/github.com/mrsmsn/chezmoi-dotfiles")" = "$REPO" ]
}

@test "trigger-on に ghq.root と sourceDir が入っている" {
    # run_onchange の再実行トリガ。どちらが変わってもリンクを張り直す必要がある。
    init_fake_source "https://github.com/mrsmsn/chezmoi-dotfiles.git"
    rendered=$(render_link)
    [[ "$rendered" == *"trigger-on: ${ROOT}|${SRC}"* ]]
}
