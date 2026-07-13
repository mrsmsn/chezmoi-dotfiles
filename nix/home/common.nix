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
    btop
    claude-code
    delta
    devbox
    direnv
    duckdb
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
    pnpm
    podman
    podman-compose
    ripgrep
    starship
    tmux
    translate-shell
    # LazyVim (nvim-treesitter main) がパーサ生成/ビルドに使う CLI。これが PATH に
    # 無いと mason が generic Linux バイナリを落としてきて NixOS の stub-ld で起動
    # 不可になる。nix 版を PATH に置き mason 版を使わせない。
    tree-sitter
    yazi
    zoxide
  ];
}
