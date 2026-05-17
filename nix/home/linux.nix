{ pkgs, ... }:

{
  home.packages = with pkgs; [
    espeak-ng
    gcc
    zsh
  ];
}
