{ pkgs, ... }:

let
  # flake.nix と同じ impure パターンで username を取得する
  # (username をハードコードしない設計なので --impure 必須)。
  username = builtins.getEnv "USER";
  gcPolicy = import ../gc-policy.nix;
in
{
  imports = [
    ./desktop.nix
    ./fonts.nix
    ./kanata.nix
    # hardware モジュール (実機の hardware-configuration.nix か CI stub) は
    # flake 側から注入する。
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # 重い input (niri=Rust / vicinae=Qt/C++ / noctalia=C++/meson) をローカル
  # フルビルドしないよう、各 upstream の cachix を substituter 登録する。これは
  # activate 後の恒常 /etc/nix/nix.conf に効く (以降の rebuild や ad-hoc nix 操作用)。
  # "新規 PC の初回ビルド" 用には flake.nix の nixConfig 側が同じ集合を担う二層構成。
  nix.settings.extra-substituters = [
    "https://niri.cachix.org"
    "https://vicinae.cachix.org"
    "https://noctalia.cachix.org"
  ];
  nix.settings.extra-trusted-public-keys = [
    "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="
    "vicinae.cachix.org-1:1kDrfienkGHPYbkpNj1mWTr7Fm1+zcenzgTizIcI3oc="
    "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
  ];

  # 世代の保持ポリシーは ../gc-policy.nix (単一ソース) を参照。
  # nix-collect-garbage --delete-older-than は「最低 N 世代残す」を表現できない
  # ため、両方をネイティブに表現できる nh clean を使う (nix.gc.automatic とは排他)。
  # nh clean all は system に加えユーザー/home-manager プロファイルも掃除する
  # (このため HM 側の clean は nix/home/nixos.nix で無効化している)。
  programs.nh = {
    enable = true;
    clean = {
      enable = true;
      dates = gcPolicy.dates;
      extraArgs = gcPolicy.keepArgs;
    };
  };

  # store 内の同一内容ファイルをハードリンクに寄せて容量を回収する (既定: 毎日 03:45)。
  nix.optimise.automatic = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # ブートメニューと ESP 上の kernel/initrd は直近 10 世代分だけ保持する。
  boot.loader.systemd-boot.configurationLimit = 10;

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

  system.stateVersion = "26.05"; # インストール時の値。変更しない。
}
