## tmuxを自動で起動する奴
# 以下の is_* ヘルパは tmux_automatically_attach_session 専用
function is_exists()                       { type "$1" >/dev/null 2>&1; }
function is_osx()                          { [[ $OSTYPE == darwin* ]]; }
function is_tmux_running()                 { [[ -n "$TMUX" ]]; }
function is_screen_running()               { [[ -n "$STY" ]]; }
function shell_has_started_interactively() { [[ -n "$PS1" ]]; }
function is_ssh_running()                  { [[ -n "$SSH_CONNECTION" ]]; }

function tmux_automatically_attach_session() {
    # 既に tmux 内ならば何もしない
    if is_tmux_running; then
        return 0
    fi

    # screen 内ならメッセージのみ出力して終了
    if is_screen_running; then
        echo "This is on screen."
        return 0
    fi

    # 非対話シェル / SSH 接続中は対象外
    if ! shell_has_started_interactively || is_ssh_running; then
        return 0
    fi

    if ! is_exists 'tmux'; then
        echo 'Error: tmux command not found' >&2
        return 1
    fi

    # detached session があればアタッチを促す
    if tmux has-session >/dev/null 2>&1 && tmux list-sessions | grep -qE '.*]$'; then
        tmux list-sessions
        echo -n "Tmux: attach? (y/N/num) "
        read -r REPLY
        if [[ -z "$REPLY" || "$REPLY" =~ ^[Yy]$ ]]; then
            if tmux attach-session; then
                echo "$(tmux -V) attached session"
                return 0
            fi
        elif [[ "$REPLY" =~ ^[0-9]+$ ]]; then
            if tmux attach -t "$REPLY"; then
                echo "$(tmux -V) attached session"
                return 0
            fi
        fi
    fi

    if is_osx && is_exists 'reattach-to-user-namespace'; then
        # macOS では default-command を user-namespace 経由にする
        local tmux_config
        tmux_config=$(cat "$HOME/.tmux.conf" <(echo 'set-option -g default-command "reattach-to-user-namespace -l $SHELL"'))
        tmux -f <(echo "$tmux_config") new-session && echo "$(tmux -V) created new session supported OS X"
    else
        tmux new-session && echo "tmux created new session"
    fi
}
tmux_automatically_attach_session
