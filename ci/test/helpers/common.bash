# `just bats` 経由なら repo は /repo にバインドされる。host から bats を直接
# 叩く逃げ道として BATS_TEST_DIRNAME から walk-up する fallback も置く。
PROJECT_ROOT="${PROJECT_ROOT:-/repo}"
if [ ! -f "${PROJECT_ROOT}/justfile" ]; then
    PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
fi

# .chezmoi.toml.tmpl 内の `.chezmoi.os` / `.chezmoi.kernel.osrelease` を sed で
# 偽装してから execute-template にかける。`--init` を付けることで
# promptStringOnce / promptBoolOnce が default 値で解決される。
render_chezmoi_toml_tmpl() {
    local os="$1" osrelease="$2"
    sed \
        -e "s|\.chezmoi\.kernel\.osrelease|\"${osrelease}\"|g" \
        -e "s|\.chezmoi\.os|\"${os}\"|g" \
        "${PROJECT_ROOT}/home/.chezmoi.toml.tmpl" \
        | chezmoi execute-template --init
}
