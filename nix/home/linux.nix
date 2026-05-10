{ pkgs, ... }:

{
  home.packages = with pkgs; [
    espeak-ng
  ];
}
