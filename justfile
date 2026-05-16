image := "chezmoi-dotfiles-ci"

# Default: run all containerised CI checks
default: ci

# Build the container image used by every test recipe
build:
    podman build -t {{image}} -f Containerfile .

# Fast subset wired into the Claude Code Stop hook: static checks +
# pure-bats assertions that don't need chezmoi apply / nix.
ci-fast: lint template-variants nix-tree-hash local-ci-hook install-unit envrcs

# run_onchange_30-write-envrcs.sh.tmpl の出力契約テスト
envrcs: build
    podman run --rm -v "$PWD":/repo:Z -w /repo {{image}} ./ci/run-bats.sh ci/test/envrcs.bats

# install.sh の内部関数のユニットテスト (TTY 判定 / CA cert 候補選択)
install-unit: build
    podman run --rm -v "$PWD":/repo:Z -w /repo {{image}} ./ci/run-bats.sh ci/test/install_unit.bats

# Full local CI (Stop hook delegates to ci-fast; this is for manual / pre-push).
ci: ci-fast template-shellcheck git-profile install-e2e

# chezmoi apply の冪等性 E2E (Nix install はスキップ、scripts は除外)
install-e2e: build
    podman run --rm -v "$PWD":/repo:Z -w /repo {{image}} ./ci/run-bats.sh ci/test/install_e2e.bats

# Reproduce the `lint` GH Actions job in a clean Linux container
lint: build
    podman run --rm -v "$PWD":/repo:Z -w /repo {{image}} ./ci/lint.sh

# Reproduce the `template-variants` job (via bats)
template-variants: build
    podman run --rm -v "$PWD":/repo:Z -w /repo {{image}} ./ci/run-bats.sh ci/test/template_variants.bats

# nix-tree-hash contract: run_onchange_20-nix-activate.sh.tmpl の冒頭コメント
# が `git rev-parse HEAD:nix` と一致する性質をアサート (chezmoi の nix/ 変更
# 検知ロジックの担保)。
nix-tree-hash: build
    podman run --rm -v "$PWD":/repo:Z -w /repo {{image}} ./ci/run-bats.sh ci/test/nix_tree_hash.bats

# Stop hook 自身の挙動契約 (.claude/hooks/local-ci.sh の JSON 出力 / skip 条件)
local-ci-hook: build
    podman run --rm -v "$PWD":/repo:Z -w /repo {{image}} ./ci/run-bats.sh ci/test/local_ci_hook.bats

# Reproduce the `template-shellcheck` job
template-shellcheck: build
    podman run --rm -v "$PWD":/repo:Z -w /repo {{image}} ./ci/template-shellcheck.sh

# Reproduce the `git-profile` job (gitdir-based work プロファイル切替の E2E)
git-profile: build
    podman run --rm -v "$PWD":/repo:Z -w /repo {{image}} ./ci/run-bats.sh ci/test/git_profile.bats

# Run the bats test suite under ci/test/ inside the CI container
bats *FILES: build
    podman run --rm -v "$PWD":/repo:Z -w /repo {{image}} ./ci/run-bats.sh {{FILES}}
