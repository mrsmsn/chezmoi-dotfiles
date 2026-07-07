{ ... }:

# CI eval 専用のダミー hardware モジュール。
# NixOS は root ("/") の fileSystems 定義が無いと "The `fileSystems' option
# does not specify your root file system." というアサーションで eval に失敗する。
# 実機では /etc/nixos/hardware-configuration.nix が供給するが、CI runner には
# それが無いので、flake の eval を通すためだけにこの最小定義を注入する。
# 実マシンでは絶対に使われない (flake 側で pathExists 分岐している)。
{
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };
}
