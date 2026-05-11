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

  # AppleSymbolicHotKeys: macOS 標準ショートカットの無効化。
  # 60: 前の入力ソースを選択         (Ctrl+Space)
  # 61: 入力メニューの次のソースを選択 (Ctrl+Opt+Space)
  # 65: Finder 検索ウィンドウを表示  (Cmd+Opt+Space)
  # Raycastのショートカットキーと競合しないように無効化する。`enabled = false`
  # 単独だと「キー未定義」と区別できず効かない macOS バージョンがあるので
  # 元の value (parameters / type) も書き戻す。
  system.defaults.CustomUserPreferences."com.apple.symbolichotkeys" = {
    AppleSymbolicHotKeys = {
      "60" = {
        enabled = false;
        value = { parameters = [ 32 49 0 ]; type = "standard"; };
      };
      "61" = {
        enabled = false;
        value = { parameters = [ 32 49 0 ]; type = "standard"; };
      };
      "65" = {
        enabled = false;
        value = { parameters = [ 65535 49 1572864 ]; type = "standard"; };
      };
    };
  };

  # CustomUserPreferences は再ログインまで反映されない事例があるので
  # activateSettings -u で即時リロードする。
  system.activationScripts.postUserActivation.text = ''
    /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
  '';

  programs.zsh.enable = true;
}
