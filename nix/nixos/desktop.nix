{ pkgs, ... }:

{
  # X11。近年の nixos-unstable では GDM/GNOME の enable は
  # services.displayManager.* / services.desktopManager.* に移動している。
  services.xserver.enable = true;
  services.xserver.xkb.layout = "us";

  services.displayManager.gdm.enable = true;

  # GNOME は残す (niri と併存)。GDM のセッション一覧に GNOME と niri が並び、
  # niri が起動できない場合でも GNOME で確実にログインできる安全網になる。
  # niri が安定稼働したら、この行を消して GNOME を撤去してよい。
  services.desktopManager.gnome.enable = true;

  # niri (scrollable-tiling Wayland compositor)。
  # programs.niri.enable が niri.desktop の GDM セッション登録・
  # xdg-desktop-portal・polkit を自動設定する。package の default は
  # pkgs.niri-stable で、flake.nix の mkPkgs に組み込んだ niri.overlays.niri
  # が供給する。
  programs.niri.enable = true;

  # このマシンは Intel iGPU (i915 / Alder Lake-N)。i915 を initrd で先に
  # ロードしないと、起動時に simpledrm が /dev/dri/card0 を先取りし、i915 は
  # 遅れて card1 になる。すると niri がプライマリ GPU 選択で描画不可の
  # simpledrm(card0) を掴み、表示できずログイン画面へ跳ね返される
  # (GNOME/mutter は賢く実 GPU を選ぶので露見しなかった)。i915 を initrd に
  # 入れて実 GPU を card0 に確定させ、simpledrm の居座りを防ぐ。
  boot.initrd.kernelModules = [ "i915" ];

  # 音声は PipeWire に統一 (PulseAudio は無効化)。
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # 日本語入力は fcitx5 + mozc。niri は text-input-v3 のみ対応するため、
  # waylandFrontend を有効にして GTK_IM_MODULE/QT_IM_MODULE に依存せず
  # text-input-v3 経由で入力する。
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.waylandFrontend = true;
    fcitx5.addons = with pkgs; [
      fcitx5-mozc
      fcitx5-gtk
    ];
  };

  # Chromium/Electron を Wayland ネイティブ (Ozone) で動かす。
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  # Noctalia のウィジェット (電池/電源プロファイル/Bluetooth) をフル機能で
  # 動かすための推奨サービス。GNOME も内部で使うので併存中は実質有効だが、
  # 将来 GNOME を撤去しても Noctalia が機能するよう明示しておく。
  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;
  hardware.bluetooth.enable = true;

  # ブラウザ。programs.chromium は NixOS ではポリシー設定のみで本体を
  # インストールしないため、Chromium は systemPackages で入れる。
  programs.firefox.enable = true;

  # KDE Connect (Pixel との連携)。システム側の役割は firewall 開放
  # (TCP/UDP 1714-1764) だけに絞り、package = null で本体は入れない。
  # 本体 + kdeconnectd/indicator の常駐は home-manager 側
  # (nix/home/nixos.nix の services.kdeconnect) が持つ。
  programs.kdeconnect = {
    enable = true;
    package = null;
  };
  # Sunshine (Moonlight ストリーミングホスト)。Android TV 側の Moonlight
  # クライアントへ低遅延で画面ミラーリングする。niri は Sunshine の Wayland
  # キャプチャが要求する wlr-export-dmabuf を実装しないため、KMS キャプチャで
  # 動かす。capSysAdmin がそのための CAP_SYS_ADMIN を security wrapper で
  # バイナリに付与する。openFirewall はペアリング/ストリーム用ポート
  # (TCP/UDP 47984-48010) を開ける。
  services.sunshine = {
    enable = true;
    capSysAdmin = true;
    openFirewall = true;
  };

  # バー/ランチャー/通知/ロック/壁紙/OSD は Noctalia デスクトップシェルが担う
  # (nix/home/nixos.nix の programs.noctalia)。以前の waybar/fuzzel/mako/
  # swaylock/swayidle/swaybg の UI 部品は Noctalia に置き換えた。wl-clipboard は
  # UI ではなく CLI クリップボードの実体なので下で別途残す。
  environment.systemPackages = with pkgs; [
    chromium
    discord

    # ターミナル (macOS は Homebrew cask、NixOS では pkgs から入れる)。
    ghostty

    # Wayland クリップボード CLI (wl-copy/wl-paste)。Noctalia の履歴 UI とは別物で、
    # lazygit 等が shell out するコピーコマンドの実体。
    wl-clipboard

    # スクリーンショット/録画のバックエンド (いずれも Noctalia が shell out する)。
    # Noctalia v5 のネイティブ screenshot コマンド
    # (noctalia msg screenshot-region / screenshot-fullscreen) は
    # grim (キャプチャ) + slurp (範囲選択) を必要とする。録画は screen_recorder
    # プラグインが wl-screenrec を使う。wl-screenrec は wlroots screencopy +
    # VA-API HW エンコード対応で、このマシンの Intel iGPU (i915) だと CPU 負荷を
    # 抑えて短尺クリップを撮れる。
    grim
    slurp
    wl-screenrec

    # 輝度キー (niri の XF86MonBrightness* バインドが spawn する)。
    # logind の SetBrightness D-Bus API 経由なので udev ルールや video グループは不要。
    brightnessctl
  ];
}
