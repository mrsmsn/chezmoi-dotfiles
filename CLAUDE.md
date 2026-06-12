# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## リポジトリの目的

macOS (Apple Silicon) / Ubuntu / WSL 用 dotfiles。**chezmoi が `$HOME` 配下のファイル**、**Nix (flakes + home-manager、macOS は nix-darwin) がパッケージとシステム設定**を管理する 2 層構成。詳細な構成・運用ルールは README.md と docs/packages.md にまとまっている。

## よく使うコマンド

ローカル CI はすべて `just` 経由 (Podman + Ubuntu コンテナで実行する。Containerfile を更新したら `just build` で再ビルド)。

```bash
just                       # = just ci (フル: ci-fast + template-shellcheck + git-profile + install-e2e)
just ci-fast               # Stop hook が呼ぶ高速サブセット (lint + template-variants + nix-tree-hash + local-ci-hook + install-unit + envrcs)
just lint                  # bash -n / zsh -n / shellcheck
just template-variants     # .chezmoi.toml.tmpl の variant 判定を bats でアサート
just template-shellcheck   # 各 variant でレンダリングしたテンプレを shellcheck
just bats ci/test/foo.bats # 単一 bats ファイルを実行 (引数なしで全件)
```

bats テストは `ci/test/*.bats` にあり、`ci/test/helpers/common.bash` で `PROJECT_ROOT` を解決する (Podman 内では `/repo`、host から直に叩く場合は `BATS_TEST_DIRNAME` から推定)。`just bats <FILE>` 経由なら自動でコンテナ内 `/repo` バインドマウントで走る。

GitHub Actions (`.github/workflows/ci.yml`) のジョブ:

- `lint` — bash/zsh syntax + shellcheck
- `flake-check` — `nix flake check --impure --no-build` (`USER=runner` を強制)
- `build-configs` — `homeConfigurations.{linux,wsl}.activationPackage` を実ビルド
- `template-variants` / `template-shellcheck` / `git-profile` — Nix を立ててから対応 bats を実行
- `bats-unit` — Nix 不要な bats (`install_unit` / `local_ci_hook` / `nix_tree_hash` / `install_e2e` / `envrcs`) を 1 job に集約
- `bootstrap-linux` — `install.sh` の E2E + 二度目の `chezmoi apply` が冪等であること + `nvim --headless +Lazy! sync` の完走

`.github/workflows/update-flake-lock.yml` が週 2 回 (月・木 06:00 JST) `nix flake update` を実行し、`nix/flake.lock` 更新 PR を自動生成する (`workflow_dispatch` で手動実行も可)。PAT secret `FLAKE_UPDATE_TOKEN` があればそれで PR を作り、無ければ `GITHUB_TOKEN` で PR を作って CI を `gh workflow run` で別途 dispatch する (default token の PR は `pull_request` イベントを発火しないため)。

dotfile を実機に反映するときは `chezmoi apply` (Nix 側を編集した場合は `run_onchange_20-nix-activate.sh.tmpl` が `darwin-rebuild switch` / `home-manager switch` を自動で呼ぶ)。

## Claude Code フック

`.claude/settings.json` で 2 つのフックが定義されている:

- **PostToolUse (`Write|Edit|MultiEdit`)** → `.claude/hooks/post-edit-check.sh`。編集したファイルに対して bash/zsh syntax と shellcheck を即時実行し、違反は `hookSpecificOutput.additionalContext` で次ターンに通知 (`.tmpl` / `.nix` はスキップ)。
- **Stop** → `.claude/hooks/local-ci.sh`。`just ci-fast` を完了ゲートとして実行、失敗時は `decision="block"` で停止を差し戻すので Claude が同じループ内で修正する。`just` または `podman` が PATH に無ければ skip メッセージだけ出して通過する。

つまり、シェルスクリプトを編集した時点で shellcheck が、応答を閉じる時点で `just ci-fast` が必ず走る。CI を再現したい場合は手で `just ci-fast` を叩けばよい。

## アーキテクチャの要点

### `.chezmoiroot = home` の含意

chezmoi が舐めるソースは **`home/` 配下だけ**。リポジトリ直下の `nix/`、`ci/`、`install.sh`、`docs/` は chezmoi の管理外で、`home/run_onchange_*.sh.tmpl` から相対パス (`{{ .chezmoi.sourceDir }}/../nix`) で参照される。新しい dotfile を追加するときは必ず `home/` 配下に置くこと。

### `run_onchange_*` スクリプトの並び

- `run_onchange_before_10-install-nix.sh.tmpl` — apply 前に Nix 本体の有無を確認
- `run_onchange_20-nix-activate.sh.tmpl` — `darwin-rebuild switch` / `home-manager switch` を variant ごとに呼ぶ
- `run_onchange_30-write-envrcs.sh.tmpl` — `ghq.root` と `work.gitdir_prefix` 配下に direnv 用 `.envrc` を書き出す (git includeIf プロファイル切替の発火点になる)

### variant とテンプレート分岐

`home/.chezmoi.toml.tmpl` が `darwin` / `linux` / `wsl` を自動判定し、テンプレ内では `{{ .variant }}` で参照できる。`run_onchange_20-nix-activate.sh.tmpl` がこの値で `darwin-rebuild` と `home-manager switch` を切り替えるので、**新しい variant 分岐を追加したらこのファイルと `ci/test/template_variants.bats` の両方を更新する必要がある**。

`sysctl -n hw.model` は Linux で失敗するため、`hw.model` 取得は `sh -c "... 2>/dev/null || true"` で包んで空文字フォールバックする。`template_variants.bats` がこの fallback を Linux ランナー上でアサートしている。

### chezmoi と nix-darwin の役割分担

判断軸: 「macOS のシステム DB (cfprefsd) が読む値か」→ `nix/darwin/`、「ユーザー HOME 配下のファイルか」→ `home/`。

- macOS の `defaults write` 相当の設定は **必ず `nix/darwin/configuration.nix` の `system.defaults.*` か `system.defaults.CustomUserPreferences.*` に宣言**する (chezmoi 側に書かない)。
- macOS GUI アプリ (.app) は Homebrew Cask (`nix/darwin/homebrew.nix`)。Sparkle 自動更新や Spotlight 連携が素直に動く。
- VSCode: 本体は Cask、拡張は `nix/home/darwin.nix` の `programs.vscode.profiles.default.extensions` (`programs.vscode.package = null` で本体インストールを抑止している)。

### Nix flake の評価

- `nix/flake.nix` は `--impure` 必須 (`builtins.getEnv "USER"` を使って username をハードコードしない設計)。CI は `USER=runner` を export している。
- `customPackagesOverlay` で `jpcal` (`nix/pkgs/jpcal.nix`) と `apm` / `claude-code` (`numtide/llm-agents.nix` flake から再公開) を nixpkgs に重ねる。
- `packages.<system>.home-manager` を再公開しているのは、activation スクリプトが `nix run nixpkgs#home-manager` で毎回 GitHub API を叩かないようにするため (CI の anonymous rate limit 対策)。

### macOS CI の扱い

`flake-check` と `build-configs` は ubuntu-latest 上で動かしている (macOS runner はコスト都合で省略)。`darwinConfigurations.default` 自体は ubuntu でも eval されるので **モジュール評価エラーは CI で検出できる**。ただし `darwin-rebuild switch` の実行や Cask ビルドは実機 (`chezmoi apply`) でのみ確認可能。

### Nix 側を編集した変更の検知

`run_onchange_20-nix-activate.sh.tmpl` の先頭コメントに `# nix-tree-hash: {{ output "git" "-C" ... "rev-parse" "HEAD:nix" }}` が埋め込まれており、`nix/` ディレクトリの tree hash が変わると chezmoi が `run_onchange_*` を再実行する。**`nix/` を編集して `chezmoi apply` を走らせるためには、その変更が git にコミット (もしくは index) されている必要がある**。この契約は `ci/test/nix_tree_hash.bats` がアサートしている。
