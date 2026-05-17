#!/usr/bin/env bash
# --print-output-on-failure: green path は静かに、失敗 test の stdout/stderr だけ
# Stop hook が読めるよう吐く。
set -euo pipefail

cd "$(dirname "$0")/.."

if [ "$#" -gt 0 ]; then
    exec bats --print-output-on-failure "$@"
fi

exec bats --print-output-on-failure --recursive ci/test
