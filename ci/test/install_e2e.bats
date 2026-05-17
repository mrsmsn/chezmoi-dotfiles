#!/usr/bin/env bats
# install.sh + chezmoi の bootstrap を fakehome に対して回す軽量 E2E。
# Nix install / git clone は INSTALL_SH_DRY=1 で skip し、bats 側で chezmoi を
# 直接呼んで template render と 2 回目 apply の冪等性を見る。Nix install 込みの
# full E2E は GH の bootstrap-linux job がカバーする。

load 'helpers/common'

teardown() {
    if [ -n "${TMPHOME:-}" ]; then
        rm -rf "$TMPHOME"
    fi
}

@test "install.sh INSTALL_SH_DRY=1 short-circuits with no side effects" {
    run env INSTALL_SH_DRY=1 bash "$PROJECT_ROOT/install.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"INSTALL_SH_DRY=1"* ]]
}

@test "chezmoi apply: 2nd run is idempotent against fakehome (scripts excluded)" {
    TMPHOME=$(mktemp -d)
    local cfg="$TMPHOME/chezmoi.toml"
    local dest="$TMPHOME/home"
    mkdir -p "$dest"

    # .chezmoi.toml.tmpl が promptStringOnce を持つので、init を経由せず data を
    # 直接埋め込んだ test config を渡す。work プロファイルは OFF。
    cat > "$cfg" <<EOF
sourceDir = "$PROJECT_ROOT/home"
destDir = "$dest"

[data]
    os = "linux"
    variant = "linux"
    is_wsl = false
    model = ""
    machine = ""

[data.git]
    user_name = ""
    user_email = ""
    gh_user_default = ""
    ssh_key = ""

[data.ghq]
    root = "~/src"

[data.work]
    gitdir_prefix = ""
    user_name = ""
    user_email = ""
    ssh_key = ""
    gh_user = ""
    bitbucket_ssh_rewrite = false
EOF

    # `--exclude=scripts` で run_onchange_*.sh.tmpl (Nix を呼ぶ) を除外。
    HOME="$dest" chezmoi --config "$cfg" apply --exclude=scripts
    HOME="$dest" chezmoi --config "$cfg" apply --exclude=scripts

    # config 経由 apply は「template が変わった、init し直せ」warning を stderr に
    # 出すので stderr は捨て、stdout (= status diff) だけ見る。
    run bash -c "HOME='$dest' chezmoi --config '$cfg' status --exclude=scripts 2>/dev/null"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
