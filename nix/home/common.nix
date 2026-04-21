{ pkgs, ... }:

let
  username = builtins.getEnv "USER";
  homeDir = if pkgs.stdenv.isDarwin then "/Users/${username}" else "/home/${username}";
in {
  home.username = username;
  home.homeDirectory = homeDir;
  home.stateVersion = "24.05";

  home.packages = [ ];
}
