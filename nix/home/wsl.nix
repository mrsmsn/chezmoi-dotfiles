{ pkgs, ... }:

let
  # gh など xdg-open/x-www-browser/www-browser/wslview の順で探すツールが
  # WSL からブラウザを開けるようにするための shim (pkgs.wslu は upstream
  # archived で nixpkgs から除去されたので自前)。
  # - cd /mnt/c: UNC CWD のまま cmd.exe を起動すると CP932 警告が UTF-8
  #   ターミナルで mojibake になるので Windows 側 CWD で起動する。
  # - start "": 第一引数を window title 扱いする start の仕様回避。
  wslview = pkgs.writeShellScriptBin "wslview" ''
    cd /mnt/c
    exec /mnt/c/Windows/System32/cmd.exe /c start "" "$@"
  '';
in
{
  home.packages = [ wslview ];
}
