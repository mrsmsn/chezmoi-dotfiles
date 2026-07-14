{ pkgs, lib, ... }:

let
  gcPolicy = import ../gc-policy.nix;
in
{
  home.packages = with pkgs; [
    espeak-ng
    # nvim-treesitter の parser ビルドに必要。macOS は Xcode CLT が cc を
    # 提供するので Nix 管理外、Linux 系のみ明示する。
    gcc
    # macOS は nix-darwin の programs.zsh.enable が system 側に入れる。
    # Linux/WSL/Android は相当機能が無いのでここで入れ、activate スクリプトが
    # chsh する。NixOS は nix/nixos/configuration.nix が system 側で別途
    # 提供するため、これとは独立 (chsh されない)。
    zsh
  ];

  # standalone home-manager variant (linux/wsl/android) の世代保持 + GC。
  # systemd user timer で `nh clean user` を回す。nixos variant は system 側の
  # `nh clean all` がユーザープロファイルまで掃除するので、nixos.nix が
  # これを false で上書きする (そのための mkDefault)。
  programs.nh.clean = {
    enable = lib.mkDefault true;
    dates = gcPolicy.dates;
    extraArgs = gcPolicy.keepArgs;
  };
}
