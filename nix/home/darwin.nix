{ pkgs, nix-vscode-extensions, ... }:

let
  vsx = nix-vscode-extensions.extensions.${pkgs.stdenv.hostPlatform.system}.vscode-marketplace;
in
{
  home.packages = with pkgs; [
    reattach-to-user-namespace
    blueutil
    tree
    jankyborders
  ];

  programs.vscode = {
    enable = true;
    # VSCode 本体は Homebrew Cask (/Applications/Visual Studio Code.app) を使う。
    # null にすることで home-manager 側の本体インストールを抑止し、拡張のみを
    # ~/.vscode/extensions/ 配下に配置する。
    package = null;
    profiles.default.extensions = [
      vsx.azemoh.one-monokai
      vsx.vscodevim.vim
    ];
  };
}
