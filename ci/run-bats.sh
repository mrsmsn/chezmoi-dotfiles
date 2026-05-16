#!/usr/bin/env bash
# bats entrypoint: walks ci/test/ recursively and runs all *.bats files.
# `--print-output-on-failure` keeps the green path quiet but dumps stdout/stderr
# of failed @test blocks, which is what the Stop hook surfaces back to Claude.
set -euo pipefail

cd "$(dirname "$0")/.."

# Allow callers to pass a subset of files / globs, e.g. `run-bats.sh ci/test/install_unit.bats`.
if [ "$#" -gt 0 ]; then
    exec bats --print-output-on-failure "$@"
fi

exec bats --print-output-on-failure --recursive ci/test
