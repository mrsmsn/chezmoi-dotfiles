{ pkgs, lib, osConfig, ... }:

# 対象アプリ (targetAppIds) にフォーカスしたら Mozc を Direct (直接入力) にする。
# fcitx5 の waylandim は seat ごとに 1 つの InputContext しか作らずアプリを
# 区別できないので、フォーカス判定は niri の event-stream 側で行う。
# Mozc のモード切替は fcitx5 が SNI (StatusNotifierItem) に出している dbusmenu の
# "Direct" 項目をクリックするのと同じ DBus 呼び出しで行う。fcitx5 の Controller1
# には action 起動 API が無く、virtual-keyboard で送ったキーは niri から fcitx5 の
# IME grab に届かないため、外部から確実に効くのはこの経路だけ。
# dbusmenu は toggle-state で現在モードも返すので、既に Direct なら何もしない。
let
  targetAppIds = [ "com.mitchellh.ghostty" ];

  watcher = pkgs.writeShellApplication {
    name = "mozc-direct-on-focus";
    runtimeInputs = [
      osConfig.programs.niri.package
      pkgs.systemd
      pkgs.jq
    ];
    text = ''
      targets=${lib.escapeShellArg (lib.concatStringsSep "\n" targetAppIds)}

      # fcitx5 の SNI は専用のバス接続なので、StatusNotifierWatcher の登録一覧
      # ("<接続名><オブジェクトパス>" 形式) から Id=Fcitx の接続名を引く
      # (fcitx5 再起動で変わるため都度解決する)。
      fcitx_sni() {
        busctl -j --user get-property org.kde.StatusNotifierWatcher /StatusNotifierWatcher \
          org.kde.StatusNotifierWatcher RegisteredStatusNotifierItems \
          | jq -r '.data[] | capture("^(?<name>[^/]+)(?<path>/.*)$") | "\(.name) \(.path)"' \
          | while read -r name path; do
              if [ "$(busctl -j --user get-property "$name" "$path" \
                       org.kde.StatusNotifierItem Id 2> /dev/null | jq -r .data)" = "Fcitx" ]; then
                echo "$name"
                return
              fi
            done
      }

      # 出力: "<menu id> <toggle-state>"
      direct_item() {
        busctl -j --user call "$1" /MenuBar com.canonical.dbusmenu GetLayout iias -- 0 -1 0 \
          | jq -r '
              .. | arrays
              | select(length == 3 and (.[1] | objects | has("icon-name"))
                       and .[1]["icon-name"].data == "fcitx_mozc_direct")
              | "\(.[0]) \(.[1]["toggle-state"].data)"
            '
      }

      set_direct() {
        sni=$(fcitx_sni || true)
        if [ -z "$sni" ]; then
          echo "fcitx5 StatusNotifierItem not found" >&2
          return
        fi
        if ! read -r id on < <(direct_item "$sni"); then
          echo "Mozc Direct menu item not found on $sni" >&2
          return
        fi
        if [ "$on" != "1" ]; then
          busctl --user call "$sni" /MenuBar com.canonical.dbusmenu Event isvu "$id" clicked s "" 0
        fi
      }

      niri msg -j event-stream \
        | jq --unbuffered -c 'select(.WindowFocusChanged) | .WindowFocusChanged.id // empty' \
        | while read -r _; do
            app_id=$(niri msg -j focused-window | jq -r '.app_id // empty')
            if [ -n "$app_id" ] && grep -qxF -- "$app_id" <<< "$targets"; then
              set_direct
            fi
          done
    '';
  };
in
{
  systemd.user.services.mozc-direct-on-focus = {
    Unit = {
      Description = "Switch Mozc to direct input when a target app is focused";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = lib.getExe watcher;
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
