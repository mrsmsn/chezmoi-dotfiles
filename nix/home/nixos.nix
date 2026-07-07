{ noctalia, ... }:

# NixOS 実機専用の home-manager 設定 (flake の nixosConfigurations だけが import
# する)。WSL/android/generic-linux の homeConfigurations には読まれないので、
# GUI デスクトップ限定の設定はここに置く。
{
  imports = [ noctalia.homeModules.default ];

  # Noctalia デスクトップシェル (niri 上のバー/ランチャー/通知/ロック/壁紙/OSD)。
  # 設定は Noctalia のコントロールセンター GUI が実行時に ~/.config/noctalia へ
  # 書き出すため、ここでは enable のみ。宣言的に固定したくなったら settings を足す。
  programs.noctalia.enable = true;
}
