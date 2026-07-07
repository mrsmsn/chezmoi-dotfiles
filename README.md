# chezmoi-dotfiles

macOS / Ubuntu / WSL(Ubuntu) / Android (Google Pixel Linux Terminal) / NixOS 向けの dotfiles。**chezmoi** で設定ファイル、**Nix** (flakes + Home Manager、macOS は nix-darwin、NixOS は NixOS モジュール) でパッケージ・システム設定を管理する。

## Bootstrap (新規環境)

```bash
curl -fsSL https://raw.githubusercontent.com/mrsmsn/chezmoi-dotfiles/main/install.sh | bash
```

スクリプトの役割:

1. Nix をインストール (NixOS 公式 installer / flakes 有効化済み)
2. chezmoi をインストール (`nix profile add nixpkgs#chezmoi`)
3. `chezmoi init --apply` でこのリポジトリを展開
4. chezmoi の `run_onchange_*` スクリプトが Nix/nix-darwin/Home Manager の活性化を実行

macOS は初回 `darwin-rebuild` 実行時に sudo プロンプトが出る場合がある。

### 新規 NixOS マシン

NixOS だけは「素の状態から `curl | bash` だけで完結」できない。先に NixOS 自体をインストールする必要があるため、手順は以下の通り。

1. NixOS を通常インストール (公式 installer が `/etc/nixos/hardware-configuration.nix` を生成する)
2. インストール後の環境で上記の `install.sh` を実行する (Nix は既にインストール済みなので Nix 自体のインストールはスキップされる)
3. `chezmoi init --apply` の中で `run_onchange_20-nix-activate.sh.tmpl` が `nixos-rebuild switch` を呼ぶ際に sudo プロンプトが出る
4. 以後 `/etc/nixos/configuration.nix` は使わなくなる (システム設定は `nix/nixos/configuration.nix` に一本化) が、**`/etc/nixos/hardware-configuration.nix` は削除しないこと**。flake が `--impure` でこのファイルを直接参照しているため、消すと `nixos-rebuild` が壊れる。

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
- Android (Pixel Linux Terminal): `nix run home-manager -- switch -b backup --flake ~/.local/share/chezmoi/nix#android --impure`
- NixOS: `sudo env HOME="$HOME" USER="$USER" nixos-rebuild switch --flake ~/.local/share/chezmoi/nix#default --impure` (素の `sudo` だと `USER=root` になり flake の `getEnv "USER"` が壊れる)

## ディレクトリ構成

```
chezmoi-dotfiles/
├── install.sh                  # 新規環境 bootstrap
├── .chezmoiroot                # chezmoi ソースディレクトリを ./home に限定
├── home/                       # chezmoi 管理対象
│   ├── .chezmoi.toml.tmpl      # OS/WSL/Android 自動判定して variant を確定
│   ├── .chezmoiignore          # 非 darwin では private_Library を無視
│   ├── dot_gitignore_global    # ~/.gitignore_global
│   ├── dot_zprofile.tmpl       # ログイン時の PATH (macOS は brew shellenv)
│   ├── dot_zshrc               # 対話 zsh の設定
│   ├── dot_claude/             # Claude Code 設定 (CLAUDE.md / settings.json / hooks)
│   ├── private_dot_config/     # ~/.config (aerospace, borders, ghostty, git, karabiner, nvim, starship, tmux, vim)
│   ├── private_Library/        # macOS の ~/Library (VSCode ユーザ設定など)
│   ├── run_onchange_before_10-install-nix.sh.tmpl
│   └── run_onchange_20-nix-activate.sh.tmpl
└── nix/                        # Nix flake (chezmoi の管理外)
    ├── flake.nix
    ├── darwin/
    │   ├── configuration.nix   # macOS システム設定
    │   ├── homebrew.nix        # Homebrew Cask (GUI アプリ) を宣言
    │   └── fonts.nix           # システムフォント
    ├── nixos/
    │   ├── configuration.nix   # NixOS システム設定 (zsh ログインシェル、timezone 等)
    │   ├── desktop.nix         # niri (Wayland)+GDM、pipewire、fcitx5-mozc、firefox/chromium
    │   ├── fonts.nix           # システムフォント (Noto CJK + HackGen)
    │   └── ci-hardware-stub.nix  # CI eval 専用のダミー hardware モジュール (実機では未使用)
    ├── home/
    │   ├── common.nix          # 全OS共通
    │   ├── darwin.nix          # macOS ユーザパッケージ + VSCode 拡張
    │   ├── linux.nix           # Ubuntu/WSL/Android (Pixel) 共通
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
| macOS キーボードショートカット (AppleSymbolicHotKeys 等) | `nix/darwin/configuration.nix` の `system.defaults.CustomUserPreferences` |
| NixOS システム設定 (デスクトップ環境、日本語入力、xremap 等) | `nix/nixos/*.nix` |

### nix-darwin と chezmoi の役割分担

- **nix-darwin** (`nix/darwin/`): macOS のシステム設定 (`system.defaults.*`, `system.defaults.CustomUserPreferences.*`)、Homebrew、フォント。`defaults write` で操作する設定は原則すべてここに宣言する。
- **chezmoi** (`home/`): `$HOME` 配下に置く dotfile (zshrc, .config/*, Library/Application Support/* など)。ユーザーが直接編集するテキスト/JSON/plist 設定が対象。
- 判断に迷ったら: 「macOS のシステム DB (cfprefsd) が読む値か」→ nix-darwin、「ユーザー HOME 配下のファイルか」→ chezmoi。

### macOS GUI アプリの方針

GUI アプリ (.app) は原則 **Homebrew Cask** で管理する (`nix/darwin/homebrew.nix`)。Spotlight / Dock / Login Items 連携や Sparkle による自前 auto-update が素直に動くため。CLI のみのツールやフォントは nixpkgs 側で扱う。VSCode 拡張は `nix-vscode-extensions` (Marketplace ミラー) 経由で home-manager の `programs.vscode` で宣言する。

初回インストール後に手動承認が必要なもの:

- **Karabiner-Elements**: 「設定 > プライバシーとセキュリティ」で DriverKit 拡張を許可。
- **Google 日本語入力**: 「設定 > キーボード > 入力ソース」で追加。
- **Scroll Reverser / Raycast**: アクセシビリティ権限を許可。
- **Tailscale**: 初回起動時に System Extension の許可とアカウントログインが必要。

対話シェルから `brew` コマンドを叩けるよう、`home/dot_zprofile.tmpl` でログイン時に `eval "$(/opt/homebrew/bin/brew shellenv)"` を実行している (Apple Silicon: `/opt/homebrew`、Intel: `/usr/local` の両方に対応)。

### variant とテンプレート分岐

chezmoi テンプレート内では `{{ .variant }}` で `darwin` / `linux` / `wsl` / `android` / `nixos` のいずれかを取得できる。`android` は Google Pixel の "Linux Terminal" 機能 (Debian aarch64 VM) を表し、kernel.osrelease に `android` を含むかで判定する。`nixos` は `.chezmoi.osRelease.id == "nixos"` で判定する。

判定順は `android > wsl > nixos > linux` (`.chezmoi.toml.tmpl` 内で上から順に評価)。そのため **NixOS を WSL 上で動かした場合は `wsl` 判定になり、`nixos` にはならない** (kernel.osrelease の `microsoft` 判定が先に当たるため)。

```
{{ if eq .variant "darwin" }}
# macOS だけに反映したい内容
{{ else if eq .variant "wsl" }}
# WSL 固有
{{ else if eq .variant "android" }}
# Pixel Linux Terminal 固有
{{ else if eq .variant "nixos" }}
# NixOS 固有
{{ else }}
# 純 Linux
{{ end }}
```

## 個人/work のセットアップ

初回 `chezmoi apply` で対話プロンプトが出る (回答は `~/.config/chezmoi/chezmoi.toml` に保存)。

| 変数 | 用途 |
| --- | --- |
| `git.user_name` | git commit の author 名 |
| `git.user_email` | git commit の email |
| `git.gh_user_default` | 普段使う GitHub アカウント名 (gh CLI 用) |
| `git.ssh_key` | git で使う SSH 鍵のファイル名 (`~/.ssh/` 配下、空ならデフォルト鍵) |
| `ghq.root` | ghq の clone 先ディレクトリ (デフォルト `~/src`) |
| `work.gitdir_prefix` | work アカウントに切り替える起点パス (例: `~/src/github.com/<work-org>/`)。空なら work 機能 OFF |

`work.gitdir_prefix` を非空にすると追加で以下が聞かれる:

| 変数 | 用途 |
| --- | --- |
| `work.user_name` | work での git commit の author 名 |
| `work.user_email` | work での git commit の email |
| `work.ssh_key` | work で使う SSH 鍵のファイル名 (空可) |
| `work.gh_user` | work で使う GitHub アカウント名 (gh CLI 用) |
| `work.bitbucket_ssh_rewrite` | Bitbucket の https URL を ssh URL に書き換える (bool) |

apply 後、`<ghq.root>` と (work ON 時) `<work.gitdir_prefix>` で `direnv allow` を 1 回ずつ叩いて有効化する。

git の `[includeIf "gitdir:..."]` は **対象パス配下の git repo の中** にいる時だけ発火する仕様。`cd <work.gitdir_prefix>` しただけの空ディレクトリで `git config -l` を叩いても personal の値のままに見えるが、これは git の挙動どおりで、その下に repo を `git clone` (or `ghq get`) したあとで repo に入って確認すれば work 値になる。

## Neovim (LazyVim)

Neovim 本体は `nix/home/common.nix` で全 OS 共通インストール、設定は [LazyVim](https://www.lazyvim.org/) の [starter](https://github.com/LazyVim/starter) を `home/private_dot_config/nvim/` に vendor 配置 (公式の `git clone starter` 手順と同じ運用)。

初回 `nvim` 起動時に `lua/config/lazy.lua` が `lazy.nvim` を `~/.local/share/nvim/lazy/lazy.nvim` に clone し、続けて `LazyVim` 本体と依存プラグイン群を一括 install する。**この間 UI が固まったように見えても数十秒〜数分待つ**。完了するとダッシュボード (mini.starter) が表示される。

日常運用:

- `:Lazy` でプラグインマネージャ UI、`:Lazy sync` で手動更新
- `:checkhealth` で LSP / treesitter / 各種依存の整合性チェック
- 設定の上書き/追加は `home/private_dot_config/nvim/lua/plugins/*.lua` に新規ファイルを置く (例: `lua/plugins/example.lua` を雛形に)
- starter 自体の upstream 追従は手動 git merge (年に数回のメジャー変更時のみ)。プラグインの自動最新化は `lazy.nvim` が `checker.enabled = true` で担うので無関係

## スコープ外

- シークレット管理 (機微値は `~/.config/chezmoi/chezmoi.toml` で持つ)
- ホスト別の machine 固有変数
- Home Manager の `programs.*` による dotfile 生成 (dotfile は chezmoi 管轄)
- Intel Mac / aarch64 Linux (Pixel Linux Terminal 以外。必要になったら `nix/flake.nix` へ追記)
