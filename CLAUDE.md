## リポジトリの目的

macOS (Apple Silicon) / Ubuntu / WSL / Android (Pixel Linux Terminal) / NixOS 用 dotfiles。**chezmoi が `$HOME` 配下のファイル**、**Nix (flakes + home-manager、macOS は nix-darwin、NixOS は NixOS モジュール) がパッケージとシステム設定**を管理する 2 層構成。詳細な構成・運用ルールは README.md と docs/packages.md にまとまっている。

## よく使うコマンド

ローカル CI はすべて `just` 経由 (Podman + Ubuntu コンテナで実行する。Containerfile を更新したら `just build` で再ビルド)。

## アーキテクチャの要点

### `.chezmoiroot = home` の含意

chezmoi が舐めるソースは **`home/` 配下だけ**。リポジトリ直下の `nix/`、`ci/`、`install.sh`、`docs/` は chezmoi の管理外で、`home/run_onchange_*.sh.tmpl` から相対パス (`{{ .chezmoi.sourceDir }}/../nix`) で参照される。新しい dotfile を追加するときは必ず `home/` 配下に置くこと。

### variant とテンプレート分岐

`home/.chezmoi.toml.tmpl` が `darwin` / `linux` / `wsl` / `android` / `nixos` を自動判定し、テンプレ内では `{{ .variant }}` で参照できる。判定順は `android > wsl > nixos > linux` で、`nixos` は `.chezmoi.osRelease.id == "nixos"` を見るため NixOS-on-WSL は `wsl` になる (kernel.osrelease の `microsoft` 判定が先に当たる)。`run_onchange_20-nix-activate.sh.tmpl` がこの値で `darwin-rebuild` / `home-manager switch` / `nixos-rebuild` を切り替えるので、**新しい variant 分岐を追加したらこのファイルと `ci/test/template_variants.bats` の両方を更新する必要がある**。

`sysctl -n hw.model` は Linux で失敗するため、`hw.model` 取得は `sh -c "... 2>/dev/null || true"` で包んで空文字フォールバックする。`template_variants.bats` がこの fallback を Linux ランナー上でアサートしている。

### chezmoi と nix-darwin の役割分担

判断軸: 「macOS のシステム DB (cfprefsd) が読む値か」→ `nix/darwin/`、「ユーザー HOME 配下のファイルか」→ `home/`。

- macOS の `defaults write` 相当の設定は **必ず `nix/darwin/configuration.nix` の `system.defaults.*` か `system.defaults.CustomUserPreferences.*` に宣言**する (chezmoi 側に書かない)。
- macOS GUI アプリ (.app) は Homebrew Cask (`nix/darwin/homebrew.nix`)。Sparkle 自動更新や Spotlight 連携が素直に動く。
- VSCode: 本体は Cask、拡張は `nix/home/darwin.nix` の `programs.vscode.profiles.default.extensions` (`programs.vscode.package = null` で本体インストールを抑止している)。
- NixOS はシステム全体を NixOS が持つので、GUI/デスクトップ環境含むシステムレベルの設定は `nix/nixos/*.nix` (`configuration.nix` / `desktop.nix` / `fonts.nix`) に宣言する。ユーザー単位限定の GUI 設定が要るようになったら `nix/home/nixos.nix` を新設するのが拡張ポイント (現状は未作成)。

### Nix flake の評価

- `nix/flake.nix` は `--impure` 必須 (`builtins.getEnv "USER"` を使って username をハードコードしない設計)。CI は `USER=runner` を export している。
- `customPackagesOverlay` で `jpcal` (`nix/pkgs/jpcal.nix`) と `apm` / `claude-code` (`numtide/llm-agents.nix` flake から再公開) を nixpkgs に重ねる。
- `packages.<system>.home-manager` を再公開しているのは、activation スクリプトが `nix run nixpkgs#home-manager` で毎回 GitHub API を叩かないようにするため (CI の anonymous rate limit 対策)。
- `nixosConfigurations.default` は `home-manager.nixosModules.home-manager` で home-manager を NixOS モジュールとして統合し、他の linux variant と同じ `nix/home/common.nix` + `linux.nix` を import する。`nixos-hardware` (`common-cpu-intel`, `common-pc-ssd`) と `xremap` はこの variant 専用の追加 input。
- **マシン固有・chezmoi 管理外の NixOS 設定は `/etc/nixos/local.nix` に置く**。`mkNixos` の modules に `hardware-configuration.nix` と同じ要領で `(if builtins.pathExists /etc/nixos/local.nix then /etc/nixos/local.nix else { })` の汎用フックがある。dotfiles リポジトリ (全 variant 共有) に入れたくない実機固有の設定 (例: VPN の strongSwan NM プラグイン有効化) の逃がし先。資格情報を伴う実行時状態 (NM の `/etc/NetworkManager/system-connections/`) はそもそも git 管理外。

### バイナリキャッシュと初回ビルド速度優先

新規マシンの初回 `nixos-rebuild --flake .#default` で重い Rust/Qt/C++ (niri / vicinae / noctalia) を**ソースビルドさせない**ことを最優先に設計している。ここを踏み外すと初回起動が数十分〜フルビルドに化ける。

- **自前 cachix を配る input には `inputs.nixpkgs.follows` を付けない**。niri / vicinae / noctalia は各自の cachix (`{niri,vicinae,noctalia}.cachix.org`) にビルド済み closure を持つが、`follows = "nixpkgs"` で nixpkgs を override すると derivation hash がずれて **必ず cache miss** し、重いビルドがローカルに落ちる (nix 公式 docs も「inputs を override すると cache miss」と明記)。逆に自前 cachix を持たず `cache.nixos.org` に乗る input (home-manager / nix-darwin / xremap / llm-agents / nix-vscode-extensions) は closure 統一のため follows を付ける。**新しい input を足すときは「自前 cachix を配っているか」で follows の有無を判断する**。
- cachix substituter は **3 箇所に同じ集合を登録**する。1 つでも欠けるか集合がズレると初回ビルドで cache miss するので、追加・変更時は 3 箇所を必ず同期させる (`run_onchange_20-nix-activate.sh.tmpl` のコメントにも同期義務が明記されている):
  1. `nix/flake.nix` トップレベルの `nixConfig.extra-substituters` — input flake の nixConfig は消費側に伝播しないのでここへ集約。**フレーク評価時 (activate 前)** から効かせる狙い。
  2. `nix/nixos/configuration.nix` の `nix.settings.extra-substituters` — activate 後の恒常 `/etc/nix/nix.conf` に効く (2 回目以降の rebuild や ad-hoc `nix` 操作用)。
  3. `home/run_onchange_20-nix-activate.sh.tmpl` の `nixos-rebuild ... --option extra-substituters` — 新規 PC の初回、まだ system config も nixConfig の許可プロンプト応答も無い状況で、root(trusted-user) から `--option` で直接渡し**プロンプト無しに完全無人ブートストラップ**する。
- xremap は module こそ flake input (`xremap.nixosModules.default`) だが、既定パッケージは crane のソースビルド (上流 cachix 無し=毎回フルビルド) なので **nixpkgs 版のパッケージを使う**ことでフルビルドを回避している。

### Nix 側を編集した変更の検知

`run_onchange_20-nix-activate.sh.tmpl` の先頭コメントに `# nix-tree-hash: {{ output "git" "-C" ... "rev-parse" "HEAD:nix" }}` が埋め込まれており、`nix/` ディレクトリの tree hash が変わると chezmoi が `run_onchange_*` を再実行する。**`nix/` を編集して `chezmoi apply` を走らせるためには、その変更が git にコミット (もしくは index) されている必要がある**。この契約は `ci/test/nix_tree_hash.bats` がアサートしている。
