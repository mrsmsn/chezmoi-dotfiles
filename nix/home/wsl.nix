{ pkgs, ... }:

let
  # WSL から URL を Windows 側のデフォルトブラウザで開くための shim。
  # `gh auth login` などが探す xdg-open / x-www-browser / www-browser /
  # wslview のうち wslview にヒットさせる目的。
  #
  # 本家 wslutilities/wslu は upstream archived のため 2026-04-08 に
  # nixpkgs から削除された (`pkgs.wslu` は throw を返す)。代替に最小限の
  # `cmd.exe /c start` ラッパを自前で持つ。empty title `""` は `start` が
  # 第一引数を title 扱いする仕様を回避するため。
  wslview = pkgs.writeShellScriptBin "wslview" ''
    exec /mnt/c/Windows/System32/cmd.exe /c start "" "$@"
  '';
in
{
  home.packages = [ wslview ];
}
