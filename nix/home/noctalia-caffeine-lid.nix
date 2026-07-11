{ pkgs, lib, ... }:

# Noctalia の caffeine ON 中は lid close でも suspend させない。
# caffeine の状態は IPC で取得できず (getter/subscribe/フック無し)、唯一の
# 観測点は caffeine が logind に取る idle inhibitor (who=noctalia, why=Caffeine)。
# これをポーリングで見張り、存在する間だけ handle-lid-switch の block inhibitor
# を保持する。handle-* inhibitor は logind.conf の変更なしで常に尊重される。
# シグナル駆動 (BlockInhibited の PropertiesChanged) は他アプリが idle inhibitor
# を先に持っていると caffeine のトグルで発火しない穴があるため採らない。
let
  watcher = pkgs.writeShellApplication {
    name = "noctalia-caffeine-lid-watcher";
    runtimeInputs = [
      pkgs.systemd
      pkgs.jq
    ];
    text = ''
      caffeine_active() {
        busctl -j call org.freedesktop.login1 /org/freedesktop/login1 \
          org.freedesktop.login1.Manager ListInhibitors \
          | jq -e '
              .data[0][]
              | select(
                  .[1] == "noctalia"
                  and .[2] == "Caffeine"
                  and (.[0] | split(":") | index("idle") != null)
                )
            ' > /dev/null
      }

      inhibit_pid=""

      release() {
        if [ -n "$inhibit_pid" ]; then
          kill "$inhibit_pid" 2> /dev/null || true
          inhibit_pid=""
          echo "released handle-lid-switch inhibitor"
        fi
      }
      trap release EXIT

      while true; do
        if caffeine_active; then
          if [ -z "$inhibit_pid" ] || ! kill -0 "$inhibit_pid" 2> /dev/null; then
            systemd-inhibit --what=handle-lid-switch --mode=block \
              --who=noctalia-caffeine-lid --why="Noctalia caffeine is active" \
              sleep infinity &
            inhibit_pid=$!
            echo "acquired handle-lid-switch inhibitor (pid $inhibit_pid)"
          fi
        else
          release
        fi
        sleep 2
      done
    '';
  };
in
{
  systemd.user.services.noctalia-caffeine-lid = {
    Unit = {
      Description = "Hold handle-lid-switch inhibitor while Noctalia caffeine is on";
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
