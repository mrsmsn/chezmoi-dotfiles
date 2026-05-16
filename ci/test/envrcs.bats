#!/usr/bin/env bats
#
# home/run_onchange_30-write-envrcs.sh.tmpl の生成条件テスト。
#
# 事故メモ: 新マシン bootstrap (chezmoi init の対話プロンプト) で
# `git.gh_user_default` を空のまま enter すると personal .envrc が
# 一切生成されない、という回帰があった (~2026-05)。元コードは
# `{{ if and .ghq.root .git.gh_user_default }}` で両方必須にしていたが、
# .envrc の本体は `export SRC_HOME=...` であって `use_gh_user "..."` 行は
# あくまでオプション。修正後は .ghq.root だけ set されていれば書き、
# use_gh_user 行は gh_user_default 有無で条件付きに分離した。
#
# 守るべき性質:
#   1. .ghq.root + .git.gh_user_default 両方ある → personal .envrc に
#      `use_gh_user "..."` と `SRC_HOME` 両方
#   2. .ghq.root のみ (.git.gh_user_default 空) → personal .envrc は
#      `SRC_HOME` だけ書かれ、`use_gh_user` 行は出ない (回帰防止)
#   3. .ghq.root が空 → personal .envrc は書かれない
#   4. .work.gitdir_prefix + .work.gh_user 両方ある → work .envrc も書く

load 'helpers/common'

TMPL="home/run_onchange_30-write-envrcs.sh.tmpl"

render_envrcs() {
    local cfg="$1"
    chezmoi --config "$cfg" execute-template < "${PROJECT_ROOT}/${TMPL}"
}

# Args: $1=path, $2=ghq_root, $3=gh_user_default, $4=work_prefix, $5=work_gh_user
write_cfg() {
    local path="$1" root="$2" gh="$3" prefix="$4" wgh="$5"
    cat > "$path" <<EOF
[data]

[data.git]
    gh_user_default = "${gh}"

[data.ghq]
    root = "${root}"

[data.work]
    gitdir_prefix = "${prefix}"
    gh_user = "${wgh}"
EOF
}

setup() {
    TMPDIR_FOR_TEST=$(mktemp -d)
    CFG="$TMPDIR_FOR_TEST/chezmoi.toml"
}

teardown() {
    if [ -n "${TMPDIR_FOR_TEST:-}" ]; then
        rm -rf "$TMPDIR_FOR_TEST"
    fi
}

@test "personal .envrc: both ghq.root and gh_user_default set → use_gh_user + SRC_HOME" {
    write_cfg "$CFG" "~/src" "mrsmsn" "" ""
    rendered=$(render_envrcs "$CFG")
    [[ "$rendered" == *'cat > "${GHQ_ROOT}/.envrc"'* ]]
    [[ "$rendered" == *'use_gh_user "mrsmsn"'* ]]
    [[ "$rendered" == *'export SRC_HOME='* ]]
    [[ "$rendered" != *'cat > "${WORK_PREFIX}/.envrc"'* ]]
}

@test "personal .envrc: ghq.root set, gh_user_default empty → SRC_HOME only (regression)" {
    write_cfg "$CFG" "~/src" "" "" ""
    rendered=$(render_envrcs "$CFG")
    [[ "$rendered" == *'cat > "${GHQ_ROOT}/.envrc"'* ]]
    [[ "$rendered" == *'export SRC_HOME='* ]]
    # use_gh_user "..." function call (= heredoc 内の `use_gh_user "<name>"`)
    # が出力されないことを確認。コメント中の `use_gh_user` 言及は除外する
    # ため open-quote まで含めてマッチさせる。
    [[ "$rendered" != *'use_gh_user "'* ]]
}

@test "personal .envrc: ghq.root empty → nothing is written" {
    write_cfg "$CFG" "" "" "" ""
    rendered=$(render_envrcs "$CFG")
    [[ "$rendered" != *'cat > "${GHQ_ROOT}/.envrc"'* ]]
    [[ "$rendered" != *'cat > "${WORK_PREFIX}/.envrc"'* ]]
}

@test "work .envrc: work.gitdir_prefix + work.gh_user set → use_gh_user + GITHUB_APM_PAT" {
    write_cfg "$CFG" "~/src" "me" "~/src/github.com/workorg/" "work-user"
    rendered=$(render_envrcs "$CFG")
    [[ "$rendered" == *'cat > "${WORK_PREFIX}/.envrc"'* ]]
    [[ "$rendered" == *'use_gh_user "work-user"'* ]]
    [[ "$rendered" == *'export GITHUB_APM_PAT='* ]]
}

@test "work .envrc: work.gitdir_prefix set, work.gh_user empty → APM_PAT only (regression)" {
    # 新マシン bootstrap で work.gh_user を空 enter したときに、
    # work prefix 配下の .envrc 自体が作られない事故の回帰防止。
    # `use_gh_user "..."` 行は省かれるが `.envrc` 本体は書かれる。
    # gh_user_default も空にしておかないと personal 側の use_gh_user 行が
    # render 結果に混ざって干渉する。
    write_cfg "$CFG" "~/src" "" "~/src/github.com/workorg/" ""
    rendered=$(render_envrcs "$CFG")
    [[ "$rendered" == *'cat > "${WORK_PREFIX}/.envrc"'* ]]
    [[ "$rendered" == *'export GITHUB_APM_PAT='* ]]
    [[ "$rendered" != *'use_gh_user "'* ]]
}

@test "work .envrc: work.gitdir_prefix empty → no work .envrc" {
    write_cfg "$CFG" "~/src" "me" "" ""
    rendered=$(render_envrcs "$CFG")
    [[ "$rendered" != *'cat > "${WORK_PREFIX}/.envrc"'* ]]
}
