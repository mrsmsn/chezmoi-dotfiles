# `just bats` 経由なら repo は /repo にバインドされる。host から bats を直接
# 叩く逃げ道として BATS_TEST_DIRNAME から walk-up する fallback も置く。
PROJECT_ROOT="${PROJECT_ROOT:-/repo}"
if [ ! -f "${PROJECT_ROOT}/justfile" ]; then
    PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
fi

# .chezmoi.toml.tmpl 内の `.chezmoi.os` / `.chezmoi.kernel.osrelease` /
# `.chezmoi.osRelease.id` を sed で偽装してから execute-template にかける。
# `--init` を付けることで promptStringOnce / promptBoolOnce が default 値で
# 解決される。
#
# CRITICAL: `.chezmoi.osRelease.id` の置換は `.chezmoi.os` の置換より先に
# 実行しなければならない。`.chezmoi.os` は `.chezmoi.osRelease.id` の文字列
# プレフィックスなので、順序を逆にすると `s|\.chezmoi\.os|...|g` が
# `.chezmoi.osRelease.id` の先頭にもマッチして壊してしまう。
render_chezmoi_toml_tmpl() {
    local os="$1" osrelease="$2" os_id="${3:-}"
    sed \
        -e "s|\.chezmoi\.osRelease\.id|\"${os_id}\"|g" \
        -e "s|\.chezmoi\.kernel\.osrelease|\"${osrelease}\"|g" \
        -e "s|\.chezmoi\.os|\"${os}\"|g" \
        "${PROJECT_ROOT}/home/.chezmoi.toml.tmpl" \
        | chezmoi execute-template --init
}
