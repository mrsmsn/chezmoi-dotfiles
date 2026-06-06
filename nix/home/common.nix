{ pkgs, lib, ... }:

let
  username = builtins.getEnv "USER";
  homeDir = if pkgs.stdenv.isDarwin then "/Users/${username}" else "/home/${username}";
in {
  # home-manager の nix-darwin/nixos 統合 (nixos/common.nix) は
  # config.users.users.${name}.home から home.homeDirectory を normal priority で
  # セットし、system user を定義しないと null になる。ここで mkForce してこちらを
  # 勝たせる。
  home.username = lib.mkForce username;
  home.homeDirectory = lib.mkForce homeDir;
  home.stateVersion = "24.05";

  home.packages = with pkgs; [
    apm
    awscli2
    bat
    claude-code
    delta
    devbox
    direnv
    fd
    fzf
    gh
    ghq
    git
    go
    jpcal
    jq
    just
    lazygit
    lsd
    neovim
    podman
    podman-compose
    ripgrep
    starship
    tmux
    translate-shell
    yazi
    zoxide
  ];
}
