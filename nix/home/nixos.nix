{ lib, osConfig, noctalia, vicinae, ... }:

# NixOS 実機専用の home-manager 設定 (flake の nixosConfigurations だけが import
# する)。WSL/android/generic-linux の homeConfigurations には読まれないので、
# GUI デスクトップ限定の設定はここに置く。
{
  imports = [
    noctalia.homeModules.default
    vicinae.homeManagerModules.default
    ./noctalia-caffeine-lid.nix
    ./mozc-direct-on-focus.nix
  ];

  # 世代保持 + GC は system 側の `nh clean all` (nix/nixos/configuration.nix) が
  # ユーザープロファイルまで掃除するので、linux.nix の user timer は重複 → 無効化。
  programs.nh.clean.enable = false;

  # Noctalia デスクトップシェル (niri 上のバー/通知/ロック/壁紙/OSD)。
  # 設定は Noctalia のコントロールセンター GUI が実行時に ~/.config/noctalia へ
  # 書き出すため、ここでは enable のみ。宣言的に固定したくなったら settings を足す。
  programs.noctalia.enable = true;

  # vicinae (Raycast 相当ランチャー)。Noctalia 付属 launcher の代わりに niri の
  # Ctrl+Space から `vicinae toggle` で開く。音量/電源/スクショ等のアクションは
  # ~/.local/share/vicinae/scripts/ の script command (chezmoi 管理) で供給する。
  programs.vicinae = {
    enable = true;
    systemd.enable = true;
    # niri で layer-shell オーバーレイ表示させる (Raycast 風のフローティング)。
    systemd.environment.USE_LAYER_SHELL = 1;
  };

  # vicinae は起動時に .desktop をスキャンした後は inotify 頼みだが、NixOS の
  # 世代切り替え (シンボリックリンク差し替え) はイベントを発火しないため、
  # server を再起動しないと新規アプリがランチャーに出ない。system.path
  # (systemPackages の集合) を unit に埋め込み、アプリ集合が変わる rebuild で
  # sd-switch に自動再起動させる。
  systemd.user.services.vicinae.Unit.X-Restart-Triggers = [ "${osConfig.system.path}" ];

  # デフォルトブラウザを Chromium に宣言的に固定する (GUI 操作等で書き換わった
  # mimeapps.list を home-manager 管理に置き換える)。claude-cli は Claude Code の
  # URL ハンドラで、管理下に入れないと mimeapps.list ごと消えるためここで維持する。
  xdg.mimeApps = {
    enable = true;
    defaultApplications =
      let
        browser = "chromium-browser.desktop";
      in
      {
        "x-scheme-handler/http" = browser;
        "x-scheme-handler/https" = browser;
        "text/html" = browser;
        "application/xhtml+xml" = browser;
        "x-scheme-handler/claude-cli" = "claude-code-url-handler.desktop";
      };
  };

  # KDE Connect。kdeconnectd を graphical-session.target 起動の user service で
  # 常駐させ、indicator で noctalia の SNI tray にアイコンを出す。firewall は
  # システム側 (nix/nixos/desktop.nix の programs.kdeconnect) が開放する。
  services.kdeconnect = {
    enable = true;
    indicator = true;
  };

  # indicator は Requires=tray.target で起動するが、noctalia (SNI watcher) は
  # niri の spawn-at-startup 起動で systemd 順序保証の外にいる。KStatusNotifierItem
  # は watcher の後着登録に対応するので通常は放置で動くが、保険として失敗時
  # リトライを付ける (HM 既定は Restart=on-abort なので mkForce が要る)。
  systemd.user.services.kdeconnect-indicator.Service = {
    Restart = lib.mkForce "on-failure";
    RestartSec = 2;
  };

  # kdeconnect-kde 同梱の xdg autostart を無効化。niri は
  # Wants=xdg-desktop-autostart.target を持ち GNOME も autostart を処理するため、
  # 放置すると上の kdeconnect.service と kdeconnectd が二重起動する
  # (2 個目は DBus 名衝突で即終了するだけだが failed unit のノイズになる)。
  xdg.configFile."autostart/org.kde.kdeconnect.daemon.desktop".text = ''
    [Desktop Entry]
    Hidden=true
  '';
}
