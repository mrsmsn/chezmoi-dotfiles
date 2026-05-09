# パッケージ一覧

このリポジトリの Nix (Home Manager + nix-darwin) で管理しているパッケージの一覧です。

定義場所: `nix/home/*.nix`、`nix/pkgs/*.nix`

## 共通 (`nix/home/common.nix`)

macOS / Linux / WSL すべての環境にインストールされるパッケージ。

| パッケージ | 用途 |
| --- | --- |
| `apm` | LLM エージェント関連ツール (`numtide/llm-agents.nix` flake から取得) |
| `awscli2` | AWS CLI v2 |
| `bat` | シンタックスハイライト付き `cat` |
| `fd` | 高速な `find` 代替 |
| `fzf` | あいまい検索 (fuzzy finder) |
| `gh` | GitHub 公式 CLI |
| `ghq` | リモートリポジトリのローカル管理 |
| `git` | バージョン管理 |
| `go` | Go 言語ツールチェーン |
| `jpcal` | 日本の祝日対応カレンダー (カスタムパッケージ) |
| `lazygit` | Git の TUI クライアント |
| `lsd` | アイコン付きの `ls` 代替 |
| `neovim` | エディタ |
| `podman` | コンテナランタイム |
| `podman-compose` | Compose 互換のコンテナオーケストレーション |
| `ripgrep` | 高速な `grep` 代替 |
| `starship` | クロスシェルプロンプト |
| `tmux` | 端末マルチプレクサ |
| `yazi` | TUI ファイルマネージャ |

## macOS 固有 (`nix/home/darwin.nix`)

| パッケージ | 用途 |
| --- | --- |
| `reattach-to-user-namespace` | tmux でクリップボード等のユーザー名前空間に再接続 |
| `blueutil` | macOS の Bluetooth コマンドライン制御 |
| `tree` | ディレクトリツリー表示 |

## Linux 固有 (`nix/home/linux.nix`)

現在固有パッケージは未定義 (空)。

## WSL 固有 (`nix/home/wsl.nix`)

現在固有パッケージは未定義 (空)。

## カスタムパッケージ (`nix/pkgs/`)

nixpkgs に存在しない、または独自にビルドしているパッケージ。`nix/flake.nix` の overlay で公開しています。

| パッケージ | 定義 | 概要 |
| --- | --- | --- |
| `jpcal` | `nix/pkgs/jpcal.nix` | [y-yagi/jpcal](https://github.com/y-yagi/jpcal) を `buildGoModule` でビルド。日本の祝日付きカレンダー |
| `apm` | overlay 経由 | `numtide/llm-agents.nix` flake の `packages.<system>.apm` を再公開 |

## Flake 入力 (`nix/flake.nix`)

パッケージの取得元となる flake 入力。

| 入力 | URL | 用途 |
| --- | --- | --- |
| `nixpkgs` | `github:NixOS/nixpkgs/nixos-unstable` | 主要なパッケージリポジトリ |
| `home-manager` | `github:nix-community/home-manager` | ユーザー環境 (dotfiles・パッケージ) 管理 |
| `nix-darwin` | `github:LnL7/nix-darwin` | macOS のシステム設定管理 |
| `llm-agents` | `github:numtide/llm-agents.nix` | `apm` 等の LLM エージェント関連パッケージ |
