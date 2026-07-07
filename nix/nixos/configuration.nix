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
    ];
  };

  system.stateVersion = "26.05"; # インストール時の値。変更しない。
}
