{ pkgs, nix-vscode-extensions, ... }:

let
  vsx = nix-vscode-extensions.extensions.${pkgs.stdenv.hostPlatform.system}.vscode-marketplace;
in
{
  home.packages = with pkgs; [
    blueutil
    tree
    jankyborders
  ];

  programs.vscode = {
    enable = true;
    # VSCode 本体は Homebrew Cask 側で入れる (Sparkle 自動更新が素直に動くため)。
    # package = null で home-manager 側の本体インストールを抑止し、拡張だけを
    # ~/.vscode/extensions/ 配下に置く。
    package = null;
    profiles.default.extensions = [
      vsx.azemoh.one-monokai
      vsx.vscodevim.vim
    ];
  };
}
