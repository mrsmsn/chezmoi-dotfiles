{ pkgs, ... }:

let
  # gh などが探す xdg-open/x-www-browser/www-browser/wslview の最後を埋める shim
  # (pkgs.wslu は upstream archived で nixpkgs から除去された)。
  # - cd /mnt/c: UNC CWD のまま cmd.exe を起動すると CP932 警告が UTF-8 ターミナル
  #   で mojibake になる。
  # - start "": 第一引数を window title として解釈する `start` の仕様回避。
  wslview = pkgs.writeShellScriptBin "wslview" ''
    cd /mnt/c
    exec /mnt/c/Windows/System32/cmd.exe /c start "" "$@"
  '';
in
{
  home.packages = [ wslview ];
}
