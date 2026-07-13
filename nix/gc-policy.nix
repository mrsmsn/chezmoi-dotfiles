# 世代保持ポリシーの単一ソース。NixOS (system の nh clean all) /
# home-manager (linux/wsl/android の nh clean user) / nix-darwin (root launchd
# daemon の nh clean all) の 3 経路で消費される。
# ポリシー: 直近 5 世代は年齢に関係なく残し、かつ 14 日以内の世代も残す。
{
  dates = "weekly";
  keepArgs = "--keep 5 --keep-since 14d";
}
