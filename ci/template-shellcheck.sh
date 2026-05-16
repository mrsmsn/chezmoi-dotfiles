#!/bin/bash
set -euo pipefail

# Mirrors the `template-shellcheck` job: render each shell template per
# variant and pipe the result into shellcheck. run_onchange_20-* は
# {{ output "git" ... }} と {{ .chezmoi.sourceDir }} を使うので除外
# (E2E は bootstrap-linux ジョブが見る)。run_onchange_30 は chezmoi data
# 値を消費するので、別途 test config を用意して render する。

variant_templates=(
    home/dot_zprofile.tmpl
    home/dot_claude/hooks/executable_notify-complete.sh.tmpl
    home/dot_claude/hooks/executable_notify-waiting.sh.tmpl
)

for variant in darwin linux wsl; do
    for tmpl in "${variant_templates[@]}"; do
        echo "=== variant=${variant} ${tmpl} ==="
        rendered=$(sed "s|\.variant|\"${variant}\"|g" "$tmpl" | chezmoi execute-template)
        if [[ -z "${rendered//[[:space:]]/}" ]]; then
            echo "(empty after rendering — skip)"
            continue
        fi
        echo "${rendered}" | shellcheck -s bash -
    done
done

# run_onchange_30 用: work ON 相当の test config を用意して render する。
# chezmoi が format を拡張子で判別するので .toml サフィックス必須。
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
)

for tmpl in "${data_templates[@]}"; do
    echo "=== ${tmpl} (work ON test config) ==="
    rendered=$(chezmoi --config "${test_config}" execute-template < "${tmpl}")
    echo "${rendered}" | shellcheck -s bash -
done

rm -f "${test_config}"
