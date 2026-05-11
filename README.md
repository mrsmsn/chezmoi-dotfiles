# chezmoi-dotfiles

macOS / Ubuntu / WSL(Ubuntu) 向けの dotfiles。**chezmoi** で設定ファイル、**Nix** (flakes + Home Manager、macOSは nix-darwin) でパッケージ・システム設定を管理する。

## Bootstrap (新規環境)

```bash
curl -fsSL https://raw.githubusercontent.com/mrsmsn/chezmoi-dotfiles/main/install.sh | bash
```

スクリプトの役割:

1. Nix をインストール (NixOS 公式 installer / flakes 有効化済み)
2. chezmoi をインストール (`nix profile install nixpkgs#chezmoi`)
3. `chezmoi init --apply` でこのリポジトリを展開
4. chezmoi の `run_onchange_*` スクリプトが Nix/nix-darwin/Home Manager の活性化を実行

macOS は初回 `darwin-rebuild` 実行時に sudo プロンプトが出る場合がある。

## 更新 (既存環境)

```bash
chezmoi update        # git pull + apply
# もしくは設定だけ反映
chezmoi apply
```

`nix/` 配下を編集した場合は `chezmoi apply` で `run_onchange_20-nix-activate.sh.tmpl` が走り、下記コマンド相当が実行される。

- macOS: `darwin-rebuild switch --flake ~/.local/share/chezmoi/nix#default --impure`
- Linux: `nix run home-manager -- switch -b backup --flake ~/.local/share/chezmoi/nix#linux --impure`
- WSL: `nix run home-manager -- switch -b backup --flake ~/.local/share/chezmoi/nix#wsl --impure`

## ディレクトリ構成

```
chezmoi-dotfiles/
├── install.sh                  # 新規環境 bootstrap
├── .chezmoiroot                # chezmoi ソースディレクトリを ./home に限定
├── home/                       # chezmoi 管理対象
│   ├── .chezmoi.toml.tmpl      # OS/WSL 自動判定して variant を確定
│   ├── .chezmoiignore          # 非 darwin では private_Library を無視
│   ├── dot_gitignore_global    # ~/.gitignore_global
│   ├── dot_zprofile.tmpl       # ログイン時の PATH (macOS は brew shellenv)
│   ├── dot_zshrc               # 対話 zsh の設定
│   ├── dot_claude/             # Claude Code 設定 (CLAUDE.md / settings.json / hooks)
│   ├── private_dot_config/     # ~/.config (aerospace, borders, ghostty, git, karabiner, starship, tmux, vim)
│   ├── private_Library/        # macOS の ~/Library (VSCode ユーザ設定など)
│   ├── run_onchange_before_10-install-nix.sh.tmpl
│   └── run_onchange_20-nix-activate.sh.tmpl
└── nix/                        # Nix flake (chezmoi の管理外)
    ├── flake.nix
    ├── darwin/
    │   ├── configuration.nix   # macOS システム設定
    │   ├── homebrew.nix        # Homebrew Cask (GUI アプリ) を宣言
    │   └── fonts.nix           # システムフォント
    ├── home/
    │   ├── common.nix          # 全OS共通
    │   ├── darwin.nix          # macOS ユーザパッケージ + VSCode 拡張
    │   ├── linux.nix           # Ubuntu/WSL 共通
    │   └── wsl.nix             # WSL 固有
    └── pkgs/                   # nixpkgs に無いカスタムパッケージ
```

## 運用ルール

| やりたいこと | 編集する場所 |
| --- | --- |
| dotfile を追加 | `home/` 配下に `dot_<name>` もしくは `dot_<name>.tmpl` |
| ユーザパッケージを追加 | `nix/home/<variant>.nix` の `home.packages` |
| 全OSで使うパッケージ | `nix/home/common.nix` の `home.packages` |
| macOS GUI アプリ (.app) を追加 | `nix/darwin/homebrew.nix` の `homebrew.casks` |
| macOS システムフォントを追加 | `nix/darwin/fonts.nix` の `fonts.packages` |
| VSCode 拡張を追加 | `nix/home/darwin.nix` の `programs.vscode.profiles.default.extensions` |
| VSCode のユーザ設定を編集 | `home/private_Library/private_Application Support/private_Code/User/{settings,keybindings}.json` (macOS) |
| macOS システム設定 | `nix/darwin/configuration.nix` |

### macOS GUI アプリの方針

GUI アプリ (.app) は原則 **Homebrew Cask** で管理する (`nix/darwin/homebrew.nix`)。Spotlight / Dock / Login Items 連携や Sparkle による自前 auto-update が素直に動くため。CLI のみのツールやフォントは nixpkgs 側で扱う。VSCode 拡張は `nix-vscode-extensions` (Marketplace ミラー) 経由で home-manager の `programs.vscode` で宣言する。

初回インストール後に手動承認が必要なもの:

- **Karabiner-Elements**: 「設定 > プライバシーとセキュリティ」で DriverKit 拡張を許可。
- **Google 日本語入力**: 「設定 > キーボード > 入力ソース」で追加。
- **Scroll Reverser / Raycast**: アクセシビリティ権限を許可。
- **Tailscale**: 初回起動時に System Extension の許可とアカウントログインが必要。

対話シェルから `brew` コマンドを叩けるよう、`home/dot_zprofile.tmpl` でログイン時に `eval "$(/opt/homebrew/bin/brew shellenv)"` を実行している (Apple Silicon: `/opt/homebrew`、Intel: `/usr/local` の両方に対応)。

### variant とテンプレート分岐

chezmoi テンプレート内では `{{ .variant }}` で `darwin` / `linux` / `wsl` のいずれかを取得できる。

```
{{ if eq .variant "darwin" }}
# macOS だけに反映したい内容
{{ else if eq .variant "wsl" }}
# WSL 固有
{{ else }}
# 純 Linux
{{ end }}
```

## スコープ外

- シークレット管理
- ホスト別の machine 固有変数
- Home Manager の `programs.*` による dotfile 生成 (dotfile は chezmoi 管轄)
- Intel Mac / aarch64 Linux (必要になったら `nix/flake.nix` へ追記)
