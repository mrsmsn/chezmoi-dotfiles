#!/bin/bash
set -euo pipefail

# work プロファイル (gitdir-based includeIf) の E2E テスト。
#
# テスト 1: 末尾 / 自動補完 (.chezmoi.toml.tmpl の正規化ロジック)
# テスト 2: work prefix 配下の git repo で git config が work 値を返すこと

# --- テスト 1: .chezmoi.toml.tmpl の末尾 / 補完 ---
# `promptStringOnce` は config の値しか見ないので、un-slashed prefix を含む
# chezmoi.toml を事前に置いて、テンプレ render 後の出力に / が付くか見る。
TMP1=$(mktemp -d)
mkdir -p "${TMP1}/cfg"
cat > "${TMP1}/cfg/chezmoi.toml" <<'EOF'
[data]
[data.git]
    user_name = "x"
    user_email = "x@example.com"
    gh_user_default = "x"
    ssh_key = ""
[data.ghq]
    root = "~/src"
[data.work]
    gitdir_prefix = "~/src/github.com/workorg"
    user_name = "w"
    user_email = "w@example.com"
    ssh_key = ""
    gh_user = "w"
    bitbucket_ssh_rewrite = false
EOF
rendered=$(chezmoi --config "${TMP1}/cfg/chezmoi.toml" execute-template --init < home/.chezmoi.toml.tmpl)
if ! echo "${rendered}" | grep -qE 'gitdir_prefix\s*=\s*"~/src/github.com/workorg/"'; then
    echo "FAIL: trailing-slash auto-append が効いてない" >&2
    echo "--- rendered chezmoi.toml ---" >&2
    echo "${rendered}" >&2
    exit 1
fi
echo "[normalize] ~/src/github.com/workorg → ~/src/github.com/workorg/ ✓"
rm -rf "${TMP1}"

# --- テスト 2: work 配下の git repo で user.email が work 値になる ---
run_case() {
    local label="$1" prefix="$2" expected_email="$3"
    local fakehome
    fakehome=$(mktemp -d)
    export HOME="${fakehome}"
    # GH runner などで XDG_CONFIG_HOME が外部 path に set されてると git も
    # chezmoi もそちらを優先するので、fakehome 配下に固定する。
    export XDG_CONFIG_HOME="${fakehome}/.config"
    mkdir -p "${HOME}/.config/git" "${HOME}/.config/chezmoi"

    local cfg="${HOME}/.config/chezmoi/chezmoi.toml"
    cat > "${cfg}" <<EOF
[data]
[data.git]
    user_name = "personal"
    user_email = "personal@example.com"
    gh_user_default = "personal"
    ssh_key = ""
[data.ghq]
    root = "~/src"
[data.work]
    gitdir_prefix = "${prefix}"
    user_name = "work"
    user_email = "work@example.com"
    ssh_key = ""
    gh_user = "work-user"
    bitbucket_ssh_rewrite = false
EOF

    # --config 明示: GH runner 等で XDG_CONFIG_HOME が別パスに set されてると
    # HOME 配下の chezmoi.toml が無視されるので、毎回パスを固定する。
    chezmoi --config "${cfg}" execute-template < home/private_dot_config/git/config.tmpl > "${HOME}/.config/git/config"
    chezmoi --config "${cfg}" execute-template < home/private_dot_config/git/config_work.tmpl > "${HOME}/.config/git/config_work"

    mkdir -p "${HOME}/src/github.com/workorg/myrepo"
    (cd "${HOME}/src/github.com/workorg/myrepo" && git init -q -b main)

    local actual
    actual=$(cd "${HOME}/src/github.com/workorg/myrepo" && git config --get user.email)
    echo "[${label}] prefix=${prefix} → user.email=${actual} (expected ${expected_email})"
    if [[ "${actual}" != "${expected_email}" ]]; then
        echo "FAIL: ${label}" >&2
        echo "--- .config/git/config ---" >&2
        cat "${HOME}/.config/git/config" >&2
        exit 1
    fi

    rm -rf "${fakehome}"
}

# 末尾 / 付き (正規ケース) → work。`~` は chezmoi が template 展開時に
# .chezmoi.homeDir に置換するので literal で渡す。
# shellcheck disable=SC2088
run_case "with-trailing-slash" "~/src/github.com/workorg/" "work@example.com"

echo "all git-profile cases passed"
