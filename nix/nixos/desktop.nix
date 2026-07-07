{ pkgs, ... }:

{
  # ログイン (display manager) は GDM、セッション本体は niri (Wayland の
  # スクロール型タイリングコンポジタ)。programs.niri (nixpkgs の NixOS module)
  # が session 登録・xdg-desktop-portal (gnome/gtk、screencast 対応)・
  # gnome-keyring・polkit を一式配線する。
  services.displayManager.gdm.enable = true;
  programs.niri.enable = true;

  # 音声は PipeWire に統一 (PulseAudio は無効化)。
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # 日本語入力は fcitx5 + mozc。
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.addons = with pkgs; [
      fcitx5-mozc
      fcitx5-gtk
    ];
  };

  # ブラウザ。programs.chromium は NixOS ではポリシー設定のみで本体を
  # インストールしないため、Chromium は systemPackages で入れる。
  programs.firefox.enable = true;
  environment.systemPackages = with pkgs; [
    chromium

    # niri のデフォルト config のキーバインドが前提とするツール:
    # Mod+T = alacritty、Mod+D = fuzzel、Super+Alt+L = swaylock。
    alacritty
    fuzzel
    swaylock
    # niri は XWayland を内蔵しない。PATH にあれば X11 アプリ起動時に
    # niri が xwayland-satellite を自動起動する。
    xwayland-satellite
  ];
}
