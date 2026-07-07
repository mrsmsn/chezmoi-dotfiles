{ pkgs, ... }:

let
  # flake.nix と同じ impure パターンで username を取得する
  # (username をハードコードしない設計なので --impure 必須)。
  username = builtins.getEnv "USER";
in
{
  imports = [
    ./desktop.nix
    ./fonts.nix
    # hardware モジュール (実機の hardware-configuration.nix か CI stub) は
    # flake 側から注入する。
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  time.timeZone = "Asia/Tokyo";

  # UI は英語、日付・通貨などの各種フォーマットは日本ロケールに寄せる。
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS        = "ja_JP.UTF-8";
    LC_IDENTIFICATION = "ja_JP.UTF-8";
    LC_MEASUREMENT    = "ja_JP.UTF-8";
    LC_MONETARY       = "ja_JP.UTF-8";
    LC_NAME           = "ja_JP.UTF-8";
    LC_NUMERIC        = "ja_JP.UTF-8";
    LC_PAPER          = "ja_JP.UTF-8";
    LC_TELEPHONE      = "ja_JP.UTF-8";
    LC_TIME           = "ja_JP.UTF-8";
  };

  services.tailscale.enable = true;
  services.printing.enable = true;

  # ログインシェルは NixOS のシステム設定 (users.users.<name>.shell) が決める。
  # generic linux の home-manager でやっている /etc/shells + chsh 方式は NixOS
  # では不可能なので、ここで zsh を有効化しつつ下でユーザの shell に割り当てる。
  programs.zsh.enable = true;

  users.users.${username} = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    shell = pkgs.zsh;
  };

  # CapsLock を Ctrl に。system モードで動かし、対象ユーザを明示する。
  services.xremap = {
    enable = true;
    serviceMode = "system";
    userName = username;
    config.modmap = [
      {
        name = "CapsLock to Ctrl";
        remap.CapsLock = "Ctrl_L";
      }
      # 内蔵キーボードの右側 3 キーが JIS キーのイベントコードを吐くので
      # 本来のキーへ戻す (右Alt=Convert/HENKAN, 右App=KanaMode/KATAKANAHIRAGANA,
      # 右Ctrl=IntlRo/RO)。右App は右Super に割り当てる。
      #
      # さらに左右 Alt を dual-role 化して macOS の英数/かな相当を作る:
      # 押しっぱなしは従来通り Alt(修飾キー)、単押しのときだけ IME 切替キーを送出する。
      #   左Alt 単押し -> Hangul_Hanja (fcitx5 の Deactivate = 英数/us 直接入力)
      #   右Alt 単押し -> Hangul       (fcitx5 の Activate   = mozc/かな)
      # あえて Henkan/Muhenkan ではなく Hangul 系キーシムを使う: Mozc は既定
      # キーマップでこれらを束縛しない (Korean 用) ため Mozc に消費されず、
      # fcitx5 の Activate/Deactivate が競合なく発火する。Henkan/Muhenkan だと
      # Mozc がカナ種切替として先に食ってしまい fcitx5 の切替が効かない。
      {
        name = "JIS right-side keys + dual-role Alt for IME toggle";
        remap = {
          HENKAN = { held = "Alt_R"; alone = "HANGEUL"; };  # 右Alt: 修飾=Alt_R / 単押し=かな
          LEFTALT = { held = "Alt_L"; alone = "HANJA"; };   # 左Alt: 修飾=Alt_L / 単押し=英数
          KATAKANAHIRAGANA = "Super_R";                     # 右App -> 右Super
          RO = "Ctrl_R";                                    # IntlRo -> 右Ctrl
        };
      }
    ];
  };

  system.stateVersion = "26.05"; # インストール時の値。変更しない。
}
