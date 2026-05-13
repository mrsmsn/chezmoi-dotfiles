#!/bin/bash
set -euo pipefail

# Mirrors the `template-shellcheck` job: render each shell template per
# variant and pipe the result into shellcheck. run_onchange_*.sh.tmpl is
# excluded because it relies on {{ output "git" ... }} and
# {{ .chezmoi.sourceDir }}, which need a full chezmoi source context.

templates=(
    home/dot_zprofile.tmpl
    home/dot_claude/hooks/executable_notify-complete.sh.tmpl
    home/dot_claude/hooks/executable_notify-waiting.sh.tmpl
)

for variant in darwin linux wsl; do
    for tmpl in "${templates[@]}"; do
        echo "=== variant=${variant} ${tmpl} ==="
        rendered=$(sed "s|\.variant|\"${variant}\"|g" "$tmpl" | chezmoi execute-template)
        if [[ -z "${rendered//[[:space:]]/}" ]]; then
            echo "(empty after rendering — skip)"
            continue
        fi
        echo "${rendered}" | shellcheck -s bash -
    done
done
