#!/bin/bash
# 各 variant でレンダリングした shell テンプレを shellcheck にかける。
# run_onchange_20-* は `{{ output "git" ... }}` と `{{ .chezmoi.sourceDir }}` を
# 使うため単発 render が難しい (E2E は bootstrap-linux job で cover)。
# run_onchange_30-* は chezmoi data に依存するので別途 test config で render する。
# SC1091: stdin 渡しでは -x で source 先を follow できないため除外。
set -euo pipefail

variant_templates=(
    home/dot_zprofile.tmpl
    home/run_onchange_before_15-brew-trust.sh.tmpl
)

for variant in darwin linux wsl android nixos; do
    for tmpl in "${variant_templates[@]}"; do
        echo "=== variant=${variant} ${tmpl} ==="
        rendered=$(sed "s|\.variant|\"${variant}\"|g" "$tmpl" | chezmoi execute-template)
        if [[ -z "${rendered//[[:space:]]/}" ]]; then
            echo "(empty after rendering — skip)"
            continue
        fi
        echo "${rendered}" | shellcheck -s bash -e SC1091 -
    done
done

# chezmoi は format を拡張子で判別するので .toml サフィックス必須。
test_config=$(mktemp --suffix=.toml)
cat > "${test_config}" <<'EOF'
[data]
[data.git]
    gh_user_default = "test"
[data.ghq]
    root = "~/src"
[data.work]
    gitdir_prefix = "~/src/github.com/TEST/"
    gh_user = "test-work"
EOF

data_templates=(
    home/run_onchange_30-write-envrcs.sh.tmpl
    home/run_onchange_35-link-ghq-src.sh.tmpl
)

for tmpl in "${data_templates[@]}"; do
    echo "=== ${tmpl} (work ON test config) ==="
    rendered=$(chezmoi --config "${test_config}" execute-template < "${tmpl}")
    echo "${rendered}" | shellcheck -s bash -e SC1091 -
done

rm -f "${test_config}"
