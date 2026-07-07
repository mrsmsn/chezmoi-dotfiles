{ pkgs, ... }:

{
  # X11。近年の nixos-unstable では GDM/GNOME の enable は
  # services.displayManager.* / services.desktopManager.* に移動している。
  services.xserver.enable = true;
  services.xserver.xkb.layout = "us";

  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

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
  ];
}
