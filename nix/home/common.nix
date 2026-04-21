{ pkgs, lib, ... }:

let
  username = builtins.getEnv "USER";
  homeDir = if pkgs.stdenv.isDarwin then "/Users/${username}" else "/home/${username}";
in {
  home.username = lib.mkDefault username;
  home.homeDirectory = lib.mkDefault homeDir;
  home.stateVersion = lib.mkDefault "24.05";

  home.packages = [ ];
}
