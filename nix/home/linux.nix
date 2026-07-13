{ pkgs, lib, ... }:

let
  gcPolicy = import ../gc-policy.nix;
in
{
  home.packages = with pkgs; [
    espeak-ng
    gcc
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
