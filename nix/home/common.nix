{ pkgs, lib, ... }:

let
  username = builtins.getEnv "USER";
  homeDir = if pkgs.stdenv.isDarwin then "/Users/${username}" else "/home/${username}";
in {
  # Use mkForce because home-manager's nix-darwin/nixos integration
  # (nixos/common.nix) sets home.homeDirectory from config.users.users.${name}.home
  # at normal priority, which is null when we don't define a system user. Our
  # values need to win over that.
  home.username = lib.mkForce username;
  home.homeDirectory = lib.mkForce homeDir;
  home.stateVersion = "24.05";

  home.packages = with pkgs; [
    apm
    awscli2
    bat
    direnv
    fd
    fzf
    gh
    ghq
    git
    go
    jpcal
    lazygit
    lsd
    neovim
    podman
    podman-compose
    ripgrep
    starship
    tmux
    yazi
  ];
}
