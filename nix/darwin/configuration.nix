{ pkgs, lib, ... }:

let
  gcPolicy = import ../gc-policy.nix;
in
{
  imports = [
    ./homebrew.nix
    ./fonts.nix
  ];

  # 世代保持 + GC (ポリシーは ../gc-policy.nix)。root daemon の `nh clean all` で
  # darwin-rebuild のシステム世代とユーザープロファイルをまとめて掃除する。
  # home-manager の programs.nh.clean (launchd agent) を使わないのは、
  # ①user 権限ではシステム世代を消せない ②HM モジュールが extraArgs を argv の
  # 1 要素として丸ごと渡すため保持フラグが壊れる (nh 側で parse error) の 2 点。
  # StartCalendarInterval は gcPolicy.dates (weekly) 相当の月曜 03:45。
  launchd.daemons.nh-clean = {
    command = "${lib.getExe pkgs.nh} clean all ${gcPolicy.keepArgs}";
    serviceConfig.StartCalendarInterval = [ { Weekday = 1; Hour = 3; Minute = 45; } ];
  };

  # NixOS 公式 installer は builder group を GID 350 で作る。nix-darwin のデフォ
  # 想定 (30000) のままだと activation の integrity check で弾かれる。
  ids.gids.nixbld = 350;

  # /etc/nix/nix.conf の真実の源はここ。`install.sh --enable-flakes` も同じ値を
  # 書くが `darwin-rebuild switch` のたびにこのモジュールが上書きする。
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
  };

  system.stateVersion = 4;

  # 内部的に nvram StartupMute=%01 を設定。
  system.startup.chime = false;

  system.defaults.NSGlobalDomain = {
    KeyRepeat = 1;
    InitialKeyRepeat = 15;
    AppleShowAllExtensions = true;
    # トラックパッドのタップをクリックと解釈する (global mouse setting)。
    "com.apple.mouse.tapBehavior" = 1;
  };

  system.defaults.finder = {
    AppleShowAllFiles = true;
    ShowPathbar = true;
    ShowStatusBar = true;
    FXPreferredViewStyle = "Nlsv"; # Nlsv = list view
    FXDefaultSearchScope = "SCcf"; # SCcf = current folder
    _FXShowPosixPathInTitle = true;
    _FXSortFoldersFirst = true;
    FXEnableExtensionChangeWarning = false;
  };

  # NSGlobalDomain の `com.apple.mouse.tapBehavior` とセットで全アプリに効かせる。
  system.defaults.trackpad.Clicking = true;

  # Raycast でアプリ起動するので Dock はピン留め無し + 自動非表示。
  system.defaults.dock = {
    autohide = true;
    autohide-delay = 0.0;
    autohide-time-modifier = 0.5;
    show-recents = false;
    persistent-apps = [ ];
    expose-group-apps = true;
  };

  system.defaults.WindowManager = {
    StandardHideWidgets = true;
    StageManagerHideWidgets = true;
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

  programs.zsh.enable = true;
}
