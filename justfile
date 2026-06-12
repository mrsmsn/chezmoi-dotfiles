image := "chezmoi-dotfiles-ci"

# `.git` がファイル (= git worktree) のときは共通 gitdir が project tree の外に
# あるので、同じ絶対パスでコンテナにバインドし `git -C /repo` を成立させる。
# 通常 checkout では空文字 = no-op。
worktree_mount := `if test -f .git; then common=$(git rev-parse --git-common-dir); (cd "$common" && printf -- '-v %s:%s:Z' "$(pwd)" "$(pwd)"); fi`

default: ci

build:
    podman build -t {{image}} -f Containerfile .

# Stop hook が走らせる高速サブセット。chezmoi apply / nix を使わないものだけ。
ci-fast: lint template-variants nix-tree-hash local-ci-hook install-unit envrcs

envrcs: build
    podman run --rm {{worktree_mount}} -v "$PWD":/repo:Z -w /repo {{image}} ./ci/run-bats.sh ci/test/envrcs.bats

install-unit: build
    podman run --rm {{worktree_mount}} -v "$PWD":/repo:Z -w /repo {{image}} ./ci/run-bats.sh ci/test/install_unit.bats

ci: ci-fast template-shellcheck git-profile install-e2e

install-e2e: build
    podman run --rm {{worktree_mount}} -v "$PWD":/repo:Z -w /repo {{image}} ./ci/run-bats.sh ci/test/install_e2e.bats

lint: build
    podman run --rm {{worktree_mount}} -v "$PWD":/repo:Z -w /repo {{image}} ./ci/lint.sh

template-variants: build
    podman run --rm {{worktree_mount}} -v "$PWD":/repo:Z -w /repo {{image}} ./ci/run-bats.sh ci/test/template_variants.bats

nix-tree-hash: build
    podman run --rm {{worktree_mount}} -v "$PWD":/repo:Z -w /repo {{image}} ./ci/run-bats.sh ci/test/nix_tree_hash.bats

local-ci-hook: build
    podman run --rm {{worktree_mount}} -v "$PWD":/repo:Z -w /repo {{image}} ./ci/run-bats.sh ci/test/local_ci_hook.bats

template-shellcheck: build
    podman run --rm {{worktree_mount}} -v "$PWD":/repo:Z -w /repo {{image}} ./ci/template-shellcheck.sh

git-profile: build
    podman run --rm {{worktree_mount}} -v "$PWD":/repo:Z -w /repo {{image}} ./ci/run-bats.sh ci/test/git_profile.bats

bats *FILES: build
    podman run --rm {{worktree_mount}} -v "$PWD":/repo:Z -w /repo {{image}} ./ci/run-bats.sh {{FILES}}

# nix flake input を更新 (引数なしで全部、引数指定で特定 input だけ)。
# 例: just nix-update / just nix-update nixpkgs / just nix-update llm-agents
nix-update *INPUTS:
    nix flake update {{INPUTS}} --flake ./nix
