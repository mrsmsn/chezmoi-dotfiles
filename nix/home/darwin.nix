{ pkgs, ... }:

{
  home.packages = with pkgs; [
    reattach-to-user-namespace
  ];
}
