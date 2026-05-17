#!/usr/bin/env bats
# work プロファイル (gitdir-based includeIf) の E2E。
#
# git の `[includeIf "gitdir:..."]` は末尾 `/` の有無でマッチ範囲が変わる
# (`/` で配下全部、無しで完全一致のみ)。.chezmoi.toml.tmpl 側で trailing-slash を
# 自動補完しているのは user が忘れたときに work プロファイルが silently 効かない
# のを防ぐため。

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

@test "work git config: repo under ghq_root/github.com/<gh_user>/ resolves to work@example.com" {
    # gitdir_prefix とは別系統で、ghq の clone 先
    # (<ghq.root>/github.com/<work.gh_user>/) 配下も work プロファイル扱いになる。
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

    mkdir -p "$HOME/src/github.com/work-user/myrepo"
    git -C "$HOME/src/github.com/work-user/myrepo" init -q -b main
    actual=$(git -C "$HOME/src/github.com/work-user/myrepo" config --get user.email)
    [ "$actual" = "work@example.com" ]
}

@test "XDG_CONFIG_HOME isolation: fakehome XDG takes precedence over external defaults" {
    # GH Actions runner は XDG_CONFIG_HOME=/etc/xdg を export する。fakehome 配下に
    # XDG を上書きしないと chezmoi.toml が読まれず、テストが host 側設定を踏む。
    TMPHOME=$(mktemp -d)
    export HOME="$TMPHOME"
    export XDG_CONFIG_HOME="$TMPHOME/.config"
    mkdir -p "$XDG_CONFIG_HOME/chezmoi"
    write_chezmoi_toml "$XDG_CONFIG_HOME/chezmoi/chezmoi.toml" ""

    run chezmoi data
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.git.user_email == "personal@example.com"'
}
