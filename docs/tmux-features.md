# tmux で実現している機能の棚卸し

> 別マルチプレクサへの移行 (herdr 移行) 時の plan ファイルの参考資料。
> 現状の tmux 設定で「何が実現されているか」を移行先に依らず列挙したもの。

## 対象ファイル

chezmoi 管理下の tmux 関連ファイル群:

| ファイル | 役割 |
|---|---|
| `home/private_dot_config/tmux/tmux.conf.tmpl` | 本体設定 (chezmoi テンプレート) |
| `home/private_dot_config/tmux/executable_pane-border.sh` | ペイン境界線の powerline 描画 (自作) |
| `home/private_dot_config/tmux/new-session` | `prefix C-r` で読む起動レイアウト |
| `home/private_dot_config/zsh/tmux.zsh` | シェル起動時の自動アタッチ |
| `home/run_onchange_after_40-tmux-plugins.sh.tmpl` | TPM ブートストラップ |
| `nix/home/common.nix` | tmux 本体インストール (home-manager) |

---

## 1. 基本設定

| 機能 | 設定 |
|---|---|
| prefix キー変更 | `C-f` |
| 履歴行数 | `history-limit 50000` |
| コピーモード | vi キーバインド (`mode-keys vi`) |
| マウス操作 | `mouse on` |
| ステータス位置 | bottom |

## 2. ペイン操作

- **Vim 風ペイン移動**: `prefix h/j/k/l` で左下上右へ (`select-pane`)
- **ペイン分割** (いずれもカレントディレクトリ継承):
  - `prefix -` → 上下分割 (縦)
  - `prefix |` → 左右分割 (横)
  - `prefix c` → 新ウィンドウ
- **ペインをウィンドウ間移動**: `prefix <` / `prefix >` で隣ウィンドウへ join-pane (repeat 可)

## 3. ウィンドウ操作

- `prefix C-h` / `prefix C-l` でウィンドウ切替 (repeat 対応、連打可)
- `prefix &` で確認なし kill-window

## 4. 設定リロード

- `prefix r` → `tmux.conf` を source してリロード
- `prefix C-r` → `new-session` レイアウトを source
  - 上下分割し、上ペインを 15 行縮小するメイン/サブ構成を再現

## 5. コピー & ペースト (macOS クリップボード連携)

- `prefix v` → コピーモード開始
- コピーモード内 (vi): `v` 選択開始 / `y`・`Enter` で確定
  - `reattach-to-user-namespace pbcopy` 経由で **macOS クリップボードへ**コピー
- `prefix p` → ペースト。クリップボード保存済みなので `Cmd-v` でもペースト可

## 6. ステータスバー

- 左: 日時 ` [%Y-%m-%d(%a) %H:%M] `
- 右: `#H:[#P]` (ホスト名:ペイン番号)
- `status-interval 1` で毎秒再描画
- 左右長さ 90
- **背景色をマシン別に切替** (chezmoi テンプレート分岐):
  - `mac-mini-m4` → colour36、それ以外 → colour60
- 文字色 colour255
- (参考) `status-left` の Wi-Fi/バッテリー表示 (`get_ssid` / `battery`) はコメントアウト済みで現在は日時のみ

## 7. ペイン境界線 — starship 風 powerline (自作)

- `pane-border-status top` + `pane-border.sh` で境界線に powerline を描画
- 表示セグメント: **OS アイコン / ディレクトリ / git ブランチ / 実行中コマンド**
- OS アイコンは variant で自動切替 (darwin= / wsl= / nixos= / linux=)
- git ブランチはブランチ内でのみ表示 (`git branch --show-current`)
- アクティブ/非アクティブで配色変化 (元 starship プロンプトと同一パレット)
- **非アクティブペインの減光** (`window-style` の fg 減光)、背景透過は維持

## 8. シェル起動時の自動アタッチ (zsh)

`tmux_automatically_attach_session` (`tmux.zsh`):

- 対話シェルかつ **非 tmux・非 screen・非 SSH** 時のみ発火
- detached session があれば一覧表示しアタッチ確認 (`y` / `N` / 番号指定)
- session が無ければ新規作成
- macOS では `reattach-to-user-namespace -l $SHELL` を default-command に注入して起動

## 9. プラグイン管理 (TPM)

- TPM のインストール先を `$XDG_CONFIG_HOME/tmux/plugins/` に統一
- **プラグイン**:
  - `tmux-plugins/tpm` (プラグインマネージャ本体)
  - `mrsmsn/tmux-translator` (自作) — コピーモードで選択したテキストを
    Google 翻訳経由で日本語にしてポップアップ表示
    (`@translate_engines 'trans google'` / `@translate_target_lang 'ja'`)
- `run_onchange_after_40-tmux-plugins.sh.tmpl` で TPM を**非対話ブートストラップ**
  - tmux.conf のハッシュを埋め込み、`@plugin` 増減時に再インストールが走る契約
  - curl|bash 経路で `XDG_CONFIG_HOME` 未設定でも失敗しないよう明示注入 (#57 対策)

## 10. パッケージ管理

- tmux 本体は Nix home-manager (`nix/home/common.nix`) でインストール

---

## 移行時のチェック観点 (herdr 移行 plan の起点)

移行先で以下が代替できるか / どう再現するかを検討する:

- [ ] prefix・キーバインド体系 (特に Vim 風移動、分割、ウィンドウ切替)
- [ ] カレントディレクトリ継承での分割/新規ペイン
- [ ] コピーモード → OS クリップボード連携 (macOS の pbcopy 相当)
- [ ] ステータスバー (日時/ホスト/ペイン番号、マシン別配色)
- [ ] ペイン境界線の powerline 表示 (OS/dir/git/cmd) と自作スクリプトの移植可否
- [ ] シェル起動時の自動アタッチ挙動 (非 SSH 時のみ等の条件)
- [ ] 翻訳ポップアップ (tmux-translator) 相当の機能
- [ ] レイアウトプリセット (`new-session` のメイン/サブ構成)
- [ ] chezmoi テンプレート分岐 (variant / machine) との統合
