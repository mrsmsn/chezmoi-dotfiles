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

  # swaylock は sway モジュールを使わないので PAM サービスを手動登録しないと
  # pam_authenticate に失敗して解錠できない。
  security.pam.services.swaylock = { };

  # Chromium/Electron を Wayland ネイティブ (Ozone) で動かす。
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  # ブラウザ。programs.chromium は NixOS ではポリシー設定のみで本体を
  # インストールしないため、Chromium は systemPackages で入れる。
  programs.firefox.enable = true;
  environment.systemPackages = with pkgs; [
    chromium

    # ターミナル (macOS は Homebrew cask、NixOS では pkgs から入れる)。
    ghostty

    # niri 付属フルスタック。WSL/android の home ビルドと共有される
    # home/linux.nix ではなく、NixOS 実機専用のこの module に置く。
    waybar     # バー
    fuzzel     # ランチャー
    mako       # 通知デーモン
    swaylock   # 画面ロック
    swayidle   # アイドル検出 (timeout でロック)
    swaybg     # 壁紙
    wl-clipboard
  ];
}
