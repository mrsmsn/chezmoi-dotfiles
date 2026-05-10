{ pkgs, ... }:

{
  imports = [
    ./homebrew.nix
    ./fonts.nix
  ];

  # NixOS 公式 installer は builder group を GID 350 で作る (旧 30000 から
  # 変更)。nix-darwin のデフォルト想定 (30000) のままだと activation の
  # integrity check で弾かれるので、実態に合わせて宣言する。
  ids.gids.nixbld = 350;

  # NixOS 公式 installer は vanilla nix-daemon を入れるため、Determinate
  # 時代の `nix.enable = false` 回避策はもう不要。`/etc/nix/nix.conf` は
  # nix-darwin にここで宣言的に管理させる。`install.sh` の `--enable-flakes`
  # も同じ値を書くが、`darwin-rebuild switch` のたびにここが上書きする
  # ので最終的な真実の源はこのモジュール。
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
  };

  system.stateVersion = 4;

  system.defaults.NSGlobalDomain = {
    KeyRepeat = 1;
    InitialKeyRepeat = 15;
  };

  programs.zsh.enable = true;
}
