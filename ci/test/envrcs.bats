#!/usr/bin/env bats
# run_onchange_30-write-envrcs.sh.tmpl の出力契約。
#
# .envrc の本体は `export SRC_HOME=...` / `export GITHUB_APM_PAT=...` で、
# `use_gh_user "..."` 行はあくまでオプション。両方必須にすると bootstrap で
# gh_user_default / work.gh_user を空 enter したとき .envrc が一切生成されない。
# このため「ベースの export 行」と「use_gh_user 行」を独立条件で出し分ける。

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

@test "personal .envrc: ghq.root set, gh_user_default empty → SRC_HOME only" {
    write_cfg "$CFG" "~/src" "" "" ""
    rendered=$(render_envrcs "$CFG")
    [[ "$rendered" == *'cat > "${GHQ_ROOT}/.envrc"'* ]]
    [[ "$rendered" == *'export SRC_HOME='* ]]
    # `use_gh_user "<name>"` 関数呼び出しが出ないことの確認。コメント中の
    # `use_gh_user` 言及は除外するため open-quote まで含めてマッチさせる。
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

@test "work .envrc: work.gitdir_prefix set, work.gh_user empty → APM_PAT only" {
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

@test "work-ghq .envrc: ghq.root + work.gh_user set → use_gh_user + GITHUB_APM_PAT under <ghq.root>/github.com/<work.gh_user>/" {
    # config.tmpl の `[includeIf "gitdir:<ghq.root>/github.com/<work.gh_user>/"]`
    # と対をなす .envrc。direnv 側でも work プロファイルが効くようにする。
    write_cfg "$CFG" "~/src" "" "" "work-user"
    rendered=$(render_envrcs "$CFG")
    [[ "$rendered" == *'cat > "${WORK_GHQ_PREFIX}/.envrc"'* ]]
    [[ "$rendered" == *'WORK_GHQ_PREFIX='* ]]
    [[ "$rendered" == *'/github.com/work-user/'* ]]
    [[ "$rendered" == *'use_gh_user "work-user"'* ]]
    [[ "$rendered" == *'export GITHUB_APM_PAT='* ]]
}

@test "work-ghq .envrc: work.gh_user empty → no work-ghq .envrc" {
    write_cfg "$CFG" "~/src" "" "" ""
    rendered=$(render_envrcs "$CFG")
    [[ "$rendered" != *'cat > "${WORK_GHQ_PREFIX}/.envrc"'* ]]
}

@test "work-ghq .envrc: ghq.root empty → no work-ghq .envrc even with work.gh_user set" {
    write_cfg "$CFG" "" "" "" "work-user"
    rendered=$(render_envrcs "$CFG")
    [[ "$rendered" != *'cat > "${WORK_GHQ_PREFIX}/.envrc"'* ]]
}
