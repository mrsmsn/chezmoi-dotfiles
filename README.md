# chezmoi-dotfiles

macOS / Ubuntu / WSL(Ubuntu) 向けの dotfiles。**chezmoi** で設定ファイル、**Nix** (flakes + Home Manager、macOSは nix-darwin) でパッケージ・システム設定を管理する。

## Bootstrap (新規環境)

```bash
curl -fsSL https://raw.githubusercontent.com/mrsmsn/chezmoi-dotfiles/main/install.sh | bash
```

スクリプトの役割:

1. Nix をインストール (Determinate Systems installer / flakes 有効化済み)
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
│   ├── .chezmoiignore
│   ├── run_onchange_before_10-install-nix.sh.tmpl
│   └── run_onchange_20-nix-activate.sh.tmpl
└── nix/                        # Nix flake (chezmoi の管理外)
    ├── flake.nix
    ├── darwin/configuration.nix
    └── home/
        ├── common.nix          # 全OS共通
        ├── darwin.nix          # macOS ユーザパッケージ
        ├── linux.nix           # Ubuntu/WSL 共通
        └── wsl.nix             # WSL 固有
```

## 運用ルール

| やりたいこと | 編集する場所 |
| --- | --- |
| dotfile を追加 | `home/` 配下に `dot_<name>` もしくは `dot_<name>.tmpl` |
| ユーザパッケージを追加 | `nix/home/<variant>.nix` の `home.packages` |
| 全OSで使うパッケージ | `nix/home/common.nix` の `home.packages` |
| macOS システム設定 | `nix/darwin/configuration.nix` |

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
