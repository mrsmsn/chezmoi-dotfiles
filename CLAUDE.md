## リポジトリの目的

macOS / Ubuntu / WSL / Android / NixOS 用 dotfiles。**chezmoi が `$HOME` 配下のファイル**、**Nix (flakes + home-manager / nix-darwin / NixOS モジュール) がパッケージとシステム設定**を管理する 2 層構成。構成・運用ルールの詳細は README.md。

## Git workflow

- 過去にPR運用していたが廃止。main一本男気で対応する。
- main pushはユーザーが行う

## よく使うコマンド

ローカル CI はすべて `just` 経由 (Podman + Ubuntu コンテナ。Containerfile を更新したら `just build` で再ビルド)。

## ルール

- `.chezmoiroot = home`: chezmoi が見るのは `home/` 配下のみ。新規 dotfile は必ず `home/` に置く (`nix/` や `ci/` は chezmoi 管理外)。
- 新しい variant 分岐を追加したら `home/run_onchange_20-nix-activate.sh.tmpl` と `ci/test/template_variants.bats` の**両方**を更新する。判定順や NixOS-on-WSL の注意は README 参照。
- macOS 設定の判断軸: 「システム DB (cfprefsd) が読む値か」→ `nix/darwin/`、「HOME 配下のファイルか」→ `home/`。詳細は README の運用ルール表。
- `nix/flake.nix` は `--impure` 必須 (`builtins.getEnv "USER"` を使うため。CI は `USER=runner` を export)。
- `packages.<system>.home-manager` の再公開は、activation スクリプトが毎回 GitHub API を叩かないための rate limit 対策。
- マシン固有・リポジトリに入れたくない NixOS 設定は `/etc/nixos/local.nix` へ (`mkNixos` に pathExists フックがある)。
- 世代保持ポリシーは `nix/gc-policy.nix` が単一ソース。
- **`nix/` を編集したら git に commit (もしくは index) しないと `chezmoi apply` が run_onchange を再実行しない** (nix-tree-hash 契約。`ci/test/nix_tree_hash.bats` がアサート)。

## バイナリキャッシュと初回ビルド速度優先

新規マシンの初回 rebuild で重い input (niri / vicinae / noctalia / llm-agents) を**ソースビルドさせない**ことを最優先に設計している。踏み外すと初回起動が数十分〜フルビルドに化ける。

- **自前バイナリキャッシュを配る input には `inputs.nixpkgs.follows` を付けない**。nixpkgs を override すると derivation hash がずれて必ず cache miss する。自前キャッシュを持たず `cache.nixos.org` に乗る input には closure 統一のため follows を付ける。新しい input を足すときは「自前キャッシュを配っているか」で判断する (cachix とは限らない。README にキャッシュ URL と公開鍵の案内が無いか確認する)。
- **flake input の更新は必ず `just nix-update`** を使う。素の `nix flake update` は `llm-agents/nixpkgs` が numtide CI のビルド rev からずれて cache miss する (`--override-input` での再 pin を just が自動化している)。
- substituter は `nix/flake.nix` の `nixConfig`、`nix/nixos/configuration.nix` の `nix.settings`、activate スクリプトの `--option` の **3 箇所に同じ集合を登録**する。1 つでも欠けると初回に cache miss する (各箇所の役割分担は activate スクリプトのコメント参照)。
- **activate スクリプトの rebuild を nh に置き換えない**。`nh os switch` はユーザー権限ビルドのため、root(trusted-user) から `--option extra-substituters` を渡す無人ブートストラップ設計と非互換。
