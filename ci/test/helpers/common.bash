# Common helpers for bats tests under ci/test/.
# Loaded from each .bats file via `load 'helpers/common'`.

# When run via `just bats` the repo is bind-mounted at /repo. Outside the
# container (rare; bats can be invoked from the host for fast iteration) we
# fall back to walking up from BATS_TEST_DIRNAME.
PROJECT_ROOT="${PROJECT_ROOT:-/repo}"
if [ ! -f "${PROJECT_ROOT}/justfile" ]; then
    PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
fi

# Render home/.chezmoi.toml.tmpl with simulated os / kernel.osrelease.
# Mirrors what ci/template-variants.sh did: sed-replace template references
# to the chezmoi runtime fields with literal strings, then drive the result
# through `chezmoi execute-template --init` so that promptStringOnce /
# promptBoolOnce evaluate to their defaults.
#
# Args: os, osrelease
# Stdout: rendered TOML
render_chezmoi_toml_tmpl() {
    local os="$1" osrelease="$2"
    sed \
        -e "s|\.chezmoi\.kernel\.osrelease|\"${osrelease}\"|g" \
        -e "s|\.chezmoi\.os|\"${os}\"|g" \
        "${PROJECT_ROOT}/home/.chezmoi.toml.tmpl" \
        | chezmoi execute-template --init
}
