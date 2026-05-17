{ pkgs, ... }:

let
  # WSL から URL を Windows 側のデフォルトブラウザで開くための shim。
  # `gh auth login` などが探す xdg-open / x-www-browser / www-browser /
  # wslview のうち wslview にヒットさせる目的。
  #
  # 本家 wslutilities/wslu は upstream archived のため 2026-04-08 に
  # nixpkgs から削除された (`pkgs.wslu` は throw を返す)。代替として
  # `explorer.exe` を直接呼ぶ最小ラッパを自前で持つ。explorer.exe は
  # Windows の URL/ファイル shell handler に処理を委譲するため、CMD を
  # 経由したときに JP Windows で出る CP932 警告メッセージ
  # ("UNC パスはサポートされません。…") が発生せず、UTF-8 ターミナルでの
  # mojibake を回避できる。
  wslview = pkgs.writeShellScriptBin "wslview" ''
    exec /mnt/c/Windows/explorer.exe "$@"
  '';
in
{
  home.packages = [ wslview ];
}
