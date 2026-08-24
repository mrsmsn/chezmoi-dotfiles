# darwin / nixos 共通モジュール。全ホストで Tailscale を常用するため単一ソース化
# (services.tailscale は両プラットフォームに存在する同名オプション)。
# tailscaled を system daemon (launchd / systemd) として常駐させ、ログイン
# セッションなしでも Tailscale SSH で到達できるようにする (ヘッドレス運用の前提)。
# darwin で GUI 版 (cask tailscale-app) を使わないのはこのため — Network
# Extension はログイン後にしか起動せず、再起動後の無人到達性を満たせない。
{ ... }:

{
  services.tailscale.enable = true;
}
