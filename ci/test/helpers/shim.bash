# PATH shim helper for bats tests that need to control whether a particular
# binary is "installed" or how it behaves (exit code, stdout). The shim
# directory is created with `make_shim_dir` and the caller is expected to
# `rm -rf` it in teardown.
#
# Usage:
#   shim_dir=$(make_shim_dir)
#   shim_cmd "$shim_dir" just 0 "ok"
#   PATH="$shim_dir:/usr/bin:/bin"

make_shim_dir() {
    mktemp -d
}

# shim_cmd <dir> <name> <exit_code> [<stdout_msg>] [<stderr_msg>]
shim_cmd() {
    local dir="$1" name="$2" exit_code="$3" stdout_msg="${4:-}" stderr_msg="${5:-}"
    cat > "$dir/$name" <<EOF
#!/usr/bin/env bash
[ -n "${stdout_msg}" ] && printf '%s\n' "${stdout_msg}"
[ -n "${stderr_msg}" ] && printf '%s\n' "${stderr_msg}" >&2
exit ${exit_code}
EOF
    chmod +x "$dir/$name"
}
