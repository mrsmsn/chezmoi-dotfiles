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
| `jankyborders` | フォーカスウィンドウに枠線を描く (CLI / 常駐は別途設定) |

## macOS GUI アプリ (`nix/darwin/homebrew.nix`)

GUI アプリは nix-darwin の `homebrew` モジュールで Cask として宣言的に管理する。Homebrew 本体は `home/run_onchange_before_10-install-nix.sh.tmpl` の darwin 分岐で自動インストールされる。

| Cask | 用途 |
| --- | --- |
| `aerospace` | i3 ライクなタイル型ウィンドウマネージャ (`nikitabobko/tap`) |
| `ghostty` | GPU アクセラレーション対応ターミナル |
| `google-chrome` | ブラウザ |
| `google-japanese-ime` | Google 日本語入力 (IME) |
| `karabiner-elements` | キーボードリマップ (DriverKit) |
| `obsidian` | Markdown ベースのノート |
| `raycast` | ランチャー / ワークフロー |
| `scroll-reverser` | スクロール方向の反転 |
| `slack` | チャット |
| `visual-studio-code` | エディタ本体 (拡張は home-manager で管理) |
| `wezterm` | GPU アクセラレーション対応ターミナル |

`onActivation` 設定:

- `autoUpdate = false` — `darwin-rebuild switch` 時に `brew update` しない (高速化のため)
- `upgrade = false` — Cask 自前の auto-update に任せる
- `cleanup = "none"` — 移行直後の安全策。手動 brew install を排除しない

## macOS システムフォント (`nix/darwin/fonts.nix`)

| パッケージ | 用途 |
| --- | --- |
| `hackgen-font` | プログラミング向け日本語フォント HackGen |
| `hackgen-nf-font` | HackGen に Nerd Fonts のグリフを統合した版 |

## VSCode 拡張 (`nix/home/darwin.nix` の `programs.vscode`)

`nix-vscode-extensions` flake (Marketplace ミラー) から取得し、home-manager 経由で `~/.vscode/extensions/` 配下に配置する。VSCode 本体は Cask 版 (`/Applications/Visual Studio Code.app`) を使う想定で `programs.vscode.package = null`。

| 拡張 | 用途 |
| --- | --- |
| `azemoh.one-monokai` | One Monokai カラーテーマ |
| `vscodevim.vim` | Vim キーバインド |

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
| `nix-vscode-extensions` | `github:nix-community/nix-vscode-extensions` | VSCode Marketplace 拡張を Nix で取得 |
