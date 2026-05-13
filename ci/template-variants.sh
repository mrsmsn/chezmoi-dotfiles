#!/bin/bash
set -euo pipefail

# Mirrors the `template-variants` job: simulate each OS by sed-replacing
# .chezmoi.os / .chezmoi.kernel.osrelease, run the template, and assert
# both variant and machine. machine is expected to be "" on the Linux
# container because sysctl hw.model fails there and the template's
# sh-wrapped fallback should kick in.

check() {
    local os="$1" osrelease="$2" expected_variant="$3" expected_machine="$4" result
    result=$(sed \
        -e "s|\.chezmoi\.kernel\.osrelease|\"${osrelease}\"|g" \
        -e "s|\.chezmoi\.os|\"${os}\"|g" \
        home/.chezmoi.toml.tmpl | chezmoi execute-template)
    echo "--- os=${os} osrelease=${osrelease} ---"
    echo "${result}"
    if ! echo "${result}" | grep -q "variant = \"${expected_variant}\""; then
        echo "FAIL: expected variant=\"${expected_variant}\"" >&2
        exit 1
    fi
    if ! echo "${result}" | grep -q "machine = \"${expected_machine}\""; then
        echo "FAIL: expected machine=\"${expected_machine}\"" >&2
        exit 1
    fi
}

check darwin "irrelevant"                         darwin ""
check linux  "6.5.0-1014-azure"                   linux  ""
check linux  "5.15.0-microsoft-standard-WSL2"     wsl    ""
