# 以下の is_* ヘルパは herdr_automatically_attach_session 専用
function is_exists()                       { type "$1" >/dev/null 2>&1; }
function is_herdr_running()                { [[ -n "$HERDR_PANE_ID" ]]; }
function is_screen_running()               { [[ -n "$STY" ]]; }
function shell_has_started_interactively() { [[ -n "$PS1" ]]; }
function is_ssh_running()                  { [[ -n "$SSH_CONNECTION" ]]; }

function herdr_automatically_attach_session() {
    # herdr ペイン内 (ネスト防止) および screen 内では起動しない
    if is_herdr_running || is_screen_running; then
        return 0
    fi

    if ! shell_has_started_interactively || is_ssh_running; then
        return 0
    fi

    if ! is_exists 'herdr'; then
        echo 'Error: herdr command not found' >&2
        return 1
    fi

    # 稼働中の session があればアタッチを促す
    local running_sessions
    running_sessions="$(herdr session list 2>/dev/null | awk 'NR > 1 && $2 == "running"')"
    if [[ -n "$running_sessions" ]]; then
        echo "$running_sessions"
        echo -n "Herdr: attach? (y/N/name) "
        read -r REPLY
        if [[ -z "$REPLY" || "$REPLY" =~ ^[Yy]$ ]]; then
            herdr
        elif [[ "$REPLY" != [Nn] ]]; then
            herdr session attach "$REPLY"
        fi
        return 0
    fi

    herdr
}
herdr_automatically_attach_session
