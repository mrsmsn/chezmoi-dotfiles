{ noctalia, vicinae, ... }:

# NixOS 実機専用の home-manager 設定 (flake の nixosConfigurations だけが import
# する)。WSL/android/generic-linux の homeConfigurations には読まれないので、
# GUI デスクトップ限定の設定はここに置く。
{
  imports = [
    noctalia.homeModules.default
    vicinae.homeManagerModules.default
    ./noctalia-caffeine-lid.nix
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
    systemd.enable = true; # user service で daemon 常駐
    # niri で layer-shell オーバーレイ表示させる (Raycast 風のフローティング)。
    systemd.environment.USE_LAYER_SHELL = 1;
  };
}
