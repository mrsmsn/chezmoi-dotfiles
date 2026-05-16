#!/usr/bin/env bats
#
# work プロファイル (gitdir-based includeIf) の E2E テスト。
# 元は ci/git-profile.sh が同じ役割を担っていた。
#
# 守るべき性質:
#   1. `.chezmoi.toml.tmpl` の trailing-slash 補完: 末尾 `/` 無しの
#      work.gitdir_prefix を渡すと正規化されること。
#   2. work prefix 配下の repo で `git config --get user.email` が
#      work@example.com を返すこと (=  config_work が includeIf でアクティブ)。
#   3. XDG_CONFIG_HOME 隔離: fakehome 配下に向けた XDG が尊重され、
#      GH Actions の default /etc/xdg のような alien path の影響を受けない
#      (PR #36 回帰防止)。

load 'helpers/common'

teardown() {
    if [ -n "${TMPHOME:-}" ]; then
        rm -rf "$TMPHOME"
    fi
}

write_chezmoi_toml() {
    # Args: $1=path, $2=work_prefix (空なら work OFF)
    local path="$1" work_prefix="$2"
    cat > "$path" <<EOF
[data]

[data.git]
    user_name = "personal"
    user_email = "personal@example.com"
    gh_user_default = "personal"
    ssh_key = ""

[data.ghq]
    root = "~/src"

[data.work]
    gitdir_prefix = "${work_prefix}"
    user_name = "work"
    user_email = "work@example.com"
    ssh_key = ""
    gh_user = "work-user"
    bitbucket_ssh_rewrite = false
EOF
}

@test "trailing-slash auto-append: ~/src/github.com/workorg → ~/src/github.com/workorg/" {
    TMPHOME=$(mktemp -d)
    local cfg="$TMPHOME/chezmoi.toml"
    # promptStringOnce 系を init で渡すため、--init かつ事前 config を渡す
    # 必要がある。`gitdir_prefix` を un-slashed で書いて、テンプレ render 後の
    # 正規化結果を確認。
    write_chezmoi_toml "$cfg" "~/src/github.com/workorg"
    rendered=$(chezmoi --config "$cfg" execute-template --init \
                   < "$PROJECT_ROOT/home/.chezmoi.toml.tmpl")
    [[ "$rendered" =~ gitdir_prefix[[:space:]]*=[[:space:]]*\"~/src/github\.com/workorg/\" ]]
}

@test "work git config: repo under work prefix resolves to work@example.com" {
    TMPHOME=$(mktemp -d)
    export HOME="$TMPHOME"
    export XDG_CONFIG_HOME="$TMPHOME/.config"
    mkdir -p "$XDG_CONFIG_HOME/git" "$XDG_CONFIG_HOME/chezmoi"

    local cfg="$XDG_CONFIG_HOME/chezmoi/chezmoi.toml"
    write_chezmoi_toml "$cfg" "~/src/github.com/workorg/"

    chezmoi --config "$cfg" execute-template \
        < "$PROJECT_ROOT/home/private_dot_config/git/config.tmpl" \
        > "$XDG_CONFIG_HOME/git/config"
    chezmoi --config "$cfg" execute-template \
        < "$PROJECT_ROOT/home/private_dot_config/git/config_work.tmpl" \
        > "$XDG_CONFIG_HOME/git/config_work"

    mkdir -p "$HOME/src/github.com/workorg/myrepo"
    git -C "$HOME/src/github.com/workorg/myrepo" init -q -b main
    actual=$(git -C "$HOME/src/github.com/workorg/myrepo" config --get user.email)
    [ "$actual" = "work@example.com" ]
}

@test "XDG_CONFIG_HOME isolation: fakehome XDG takes precedence over external defaults" {
    # PR #36 で fix した「GH Actions が XDG_CONFIG_HOME=/etc/xdg をセット
    # するから fakehome 配下の chezmoi.toml が無視される」事故の回帰防止。
    # fakehome 配下に XDG を向け、その下の config がきちんと読まれることを
    # chezmoi data で確認する。
    TMPHOME=$(mktemp -d)
    export HOME="$TMPHOME"
    export XDG_CONFIG_HOME="$TMPHOME/.config"
    mkdir -p "$XDG_CONFIG_HOME/chezmoi"
    write_chezmoi_toml "$XDG_CONFIG_HOME/chezmoi/chezmoi.toml" ""

    run chezmoi data
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.git.user_email == "personal@example.com"'
}
