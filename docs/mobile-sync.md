# スマホ (Pixel) 連携 — KDE Connect

NixOS 側は宣言済み (`nix/nixos/desktop.nix` の firewall 開放 + `nix/home/nixos.nix` の kdeconnectd/indicator 常駐)。以下は Android 側のリポジトリ外手作業。

## セットアップ

1. Pixel に KDE Connect アプリを入れる (Play Store / F-Droid)。
2. 同一 LAN で自動検出されるので、どちらかからペアリング要求を送る。PC 側は noctalia 通知で承認するか、CLI で:

   ```sh
   kdeconnect-cli --refresh && kdeconnect-cli -l
   kdeconnect-cli --pair -d <device-id>
   ```

## Tailscale (外出先から使う)

KDE Connect の自動検出は UDP ブロードキャストなので tailnet を越えない。一度だけ手動登録する:

1. 両デバイスが同一 tailnet に接続していることを確認。
2. Android アプリの「Add devices by IP」に PC の Tailscale IP (100.x.x.x) を登録。以降は自動再接続される。
3. Android の Tailscale アプリで「Allow local network access」を有効にすると、LAN 内の自動検出と Tailscale 直接続を両立できる。

まれに Tailscale 有効時に接続できない報告あり (tailscale/tailscale#14476)。外出先で使う前に自宅で疎通確認しておく。

## クリップボード

- **PC → Android**: 自動で同期される。
- **Android → PC**: Android 10+ の制限でバックグラウンドの自動読み取りは不可。手動送信で運用する:
  - Android 14+ なら Quick Settings に「Send clipboard」タイルを配置するのが最短。
  - もしくは KDE Connect の常駐通知内「Send clipboard」ボタン。
- 常駐通知は無効化しないこと。無効化すると Android→PC の送信手段が消える (KDE Bug 446366)。
