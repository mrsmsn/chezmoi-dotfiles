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
  #
  # `cd /mnt/c` してから cmd.exe を起動するのが要点。WSL ホーム配下
  # (UNC `\\wsl.localhost\...`) を CWD のまま cmd.exe を起動すると JP
  # Windows では CP932 警告 ("現在のディレクトリは CMD.EXE で開始しました
  # 。UNC パスはサポートされません。Windows ディレクトリを使用します。")
  # が stderr に流れ、UTF-8 ターミナルで mojibake になる。gh auth login
  # が CWD を引き継いだまま wslview を呼ぶケースで顕在化した。Windows
  # 側のパスから起動すれば警告は出ない。
  #
  # explorer.exe で代替する案もあるが、binfmt_misc 経由の直接 exec で
  # "Exec format error" を出すケースが報告されており、互換性の高い
  # cmd.exe を引き続き採用する。
  wslview = pkgs.writeShellScriptBin "wslview" ''
    cd /mnt/c
    exec /mnt/c/Windows/System32/cmd.exe /c start "" "$@"
  '';
in
{
  home.packages = [ wslview ];
}
