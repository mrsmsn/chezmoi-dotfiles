#!/usr/bin/env bats
#
# install.sh と chezmoi の bootstrap フローを fakehome に対して回す E2E。
# Nix install / chezmoi init の git clone といった重いステップは
# `INSTALL_SH_DRY=1` で全部スキップし、代わりに bats 側で chezmoi を
# 直接呼んで template render / apply / 二度目 apply の冪等性をアサート。
#
# 守るべき性質:
#   1. INSTALL_SH_DRY=1 で main が副作用なく early return する
#   2. chezmoi apply を 2 回かけて 2 回目で `chezmoi status` が空
#      (= run_onchange でない target ファイルが冪等に展開される)
#
# GH の bootstrap-linux ジョブが Nix install まで含む full E2E を担うので、
# ここは「テンプレ render と平和な apply が壊れていない」ことの早期検出。

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

    # 本物の .chezmoi.toml.tmpl が promptStringOnce を持つので、init を
    # 経由せず data を直接埋め込んだ test config を渡す。値は全て CI 用の
    # ダミーで、work プロファイルは OFF。
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
    # 通常ファイルだけが target に展開される。
    HOME="$dest" chezmoi --config "$cfg" apply --exclude=scripts
    # 二度目 apply
    HOME="$dest" chezmoi --config "$cfg" apply --exclude=scripts

    # chezmoi は `.chezmoi.toml.tmpl` を持つ source に対して config 経由で
    # 走ると「template が変わった、init し直せ」warning を stderr に出す。
    # 既存ステートの比較 (=空 diff) は stdout でアサートできるので stderr は
    # 捨てる。
    run bash -c "HOME='$dest' chezmoi --config '$cfg' status --exclude=scripts 2>/dev/null"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
