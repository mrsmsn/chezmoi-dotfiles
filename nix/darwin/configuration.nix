{ pkgs, ... }:

{
  imports = [
    ./homebrew.nix
    ./fonts.nix
  ];

  # NixOS 公式 installer は vanilla nix-daemon を入れるため、Determinate
  # 時代の `nix.enable = false` 回避策はもう不要。`/etc/nix/nix.conf` は
  # nix-darwin にここで宣言的に管理させる。`install.sh` の `--enable-flakes`
  # も同じ値を書くが、`darwin-rebuild switch` のたびにここが上書きする
  # ので最終的な真実の源はこのモジュール。
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
  };

  system.stateVersion = 4;

  programs.zsh.enable = true;
}
