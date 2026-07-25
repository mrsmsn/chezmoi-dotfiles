image := "chezmoi-dotfiles-ci"

# `.git` がファイル (= git worktree) のときは共通 gitdir が project tree の外に
# あるので、同じ絶対パスでコンテナにバインドし `git -C /repo` を成立させる。
# 通常 checkout では空文字 = no-op。
worktree_mount := `if test -f .git; then common=$(git rev-parse --git-common-dir); (cd "$common" && printf -- '-v %s:%s:Z' "$(pwd)" "$(pwd)"); fi`

# Stop hook が走らせる高速サブセット。chezmoi apply / nix を使わないものだけ。
ci-fast: lint template-variants nix-tree-hash local-ci-hook install-unit envrcs

build:
    podman build -t {{image}} -f Containerfile .

envrcs: build
    podman run --rm {{worktree_mount}} -v "$PWD":/repo:Z -w /repo {{image}} ./ci/run-bats.sh ci/test/envrcs.bats

install-unit: build
    podman run --rm {{worktree_mount}} -v "$PWD":/repo:Z -w /repo {{image}} ./ci/run-bats.sh ci/test/install_unit.bats

lint: build
    podman run --rm {{worktree_mount}} -v "$PWD":/repo:Z -w /repo {{image}} ./ci/lint.sh

template-variants: build
    podman run --rm {{worktree_mount}} -v "$PWD":/repo:Z -w /repo {{image}} ./ci/run-bats.sh ci/test/template_variants.bats

nix-tree-hash: build
    podman run --rm {{worktree_mount}} -v "$PWD":/repo:Z -w /repo {{image}} ./ci/run-bats.sh ci/test/nix_tree_hash.bats

local-ci-hook: build
    podman run --rm {{worktree_mount}} -v "$PWD":/repo:Z -w /repo {{image}} ./ci/run-bats.sh ci/test/local_ci_hook.bats

# nix flake input を更新 (引数なしで全部、引数指定で特定 input だけ)。
# 例: just nix-update / just nix-update nixpkgs / just nix-update llm-agents
#
# 更新後、llm-agents/nixpkgs を llm-agents 自身の lock が pin する rev に再 pin
# する。nix は親 lock を作るとき子 flake の lock を引き継がず input spec を最新
# 解決するため、放置すると numtide CI がビルドした closure と derivation hash が
# ずれ、cache.numtide.com を miss して herdr (Rust) がローカルソースビルドに化ける。
nix-update *INPUTS:
    nix flake update {{INPUTS}} --flake ./nix
    rev="$(nix flake metadata --json "github:numtide/llm-agents.nix/$(jq -r '.nodes[.nodes.root.inputs["llm-agents"]].locked.rev' nix/flake.lock)" | jq -r '.locks.nodes[.locks.nodes.root.inputs.nixpkgs].locked.rev')" && nix flake lock ./nix --override-input llm-agents/nixpkgs "github:NixOS/nixpkgs/${rev}"
