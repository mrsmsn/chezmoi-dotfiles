image := "chezmoi-dotfiles-ci"

# `.git` がファイル (= git worktree) のときは共通 gitdir が project tree の外に
# あるので、同じ絶対パスでコンテナにバインドし `git -C /repo` を成立させる。
# 通常 checkout では空文字 = no-op。
worktree_mount := `if test -f .git; then common=$(git rev-parse --git-common-dir); (cd "$common" && printf -- '-v %s:%s:Z' "$(pwd)" "$(pwd)"); fi`

# 高速サブセット。chezmoi apply / nix を使わないものだけ。
ci-fast: lint template-variants nix-tree-hash install-unit envrcs ghq-link

build:
    podman build -t {{image}} -f Containerfile .

envrcs: build
    podman run --rm {{worktree_mount}} -v "$PWD":/repo:Z -w /repo {{image}} ./ci/run-bats.sh ci/test/envrcs.bats

ghq-link: build
    podman run --rm {{worktree_mount}} -v "$PWD":/repo:Z -w /repo {{image}} ./ci/run-bats.sh ci/test/ghq_link.bats

install-unit: build
    podman run --rm {{worktree_mount}} -v "$PWD":/repo:Z -w /repo {{image}} ./ci/run-bats.sh ci/test/install_unit.bats

lint: build
    podman run --rm {{worktree_mount}} -v "$PWD":/repo:Z -w /repo {{image}} ./ci/lint.sh

template-variants: build
    podman run --rm {{worktree_mount}} -v "$PWD":/repo:Z -w /repo {{image}} ./ci/run-bats.sh ci/test/template_variants.bats

nix-tree-hash: build
    podman run --rm {{worktree_mount}} -v "$PWD":/repo:Z -w /repo {{image}} ./ci/run-bats.sh ci/test/nix_tree_hash.bats

# nix flake input を更新 (引数なしで全部、引数指定で特定 input だけ)。
# 例: just nix-update / just nix-update nixpkgs / just nix-update llm-agents
#
# 更新後、llm-agents/nixpkgs を llm-agents 自身の lock が pin する rev に再 pin
# する。nix は親 lock を作るとき子 flake の lock を引き継がず input spec を最新
# 解決するため、放置すると numtide CI がビルドした closure と derivation hash が
# ずれ、cache.numtide.com を miss して herdr (Rust) がローカルソースビルドに化ける。
#
# さらに root nixpkgs を niri-flake 自身の lock が pin する rev に再 pin する。
# niri は overlay 方式 (root nixpkgs で callPackage) なので、root nixpkgs が
# niri-flake の pin から先行すると (1) niri.cachix.org のキャッシュと derivation
# hash がずれて niri (Rust) がソースビルドに化け、(2) niri-flake が未追従の
# nixpkgs 破壊的変更 (例: 2026-08 の libdisplay-info_0_2 alias 削除) で eval が
# 落ちる。両者が一致している間だけ cache hit + eval 成功が成立する。
nix-update *INPUTS:
    nix flake update {{INPUTS}} --flake ./nix
    rev="$(nix flake metadata --json "github:numtide/llm-agents.nix/$(jq -r '.nodes[.nodes.root.inputs["llm-agents"]].locked.rev' nix/flake.lock)" | jq -r '.locks.nodes[.locks.nodes.root.inputs.nixpkgs].locked.rev')" && nix flake lock ./nix --override-input llm-agents/nixpkgs "github:NixOS/nixpkgs/${rev}"
    rev="$(nix flake metadata --json "github:sodiboo/niri-flake/$(jq -r '.nodes[.nodes.root.inputs.niri].locked.rev' nix/flake.lock)" | jq -r '.locks.nodes[.locks.nodes.root.inputs.nixpkgs].locked.rev')" && nix flake lock ./nix --override-input nixpkgs "github:NixOS/nixpkgs/${rev}"
