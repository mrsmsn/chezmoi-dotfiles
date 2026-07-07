# NixOS のユーザー単位 GUI 設定。
# NixOS の programs.chromium は enterprise policy 設定のみで本体をインストール
# しないため、本体もインストールされる home-manager 側の programs.chromium で
# 宣言する (firefox は system 側 desktop.nix の programs.firefox)。
{ ... }:

{
  programs.chromium.enable = true;
}
