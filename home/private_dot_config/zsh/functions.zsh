### ghq.root を複数設定している場合に対応するため -p を使用。
### ${HOME}/src/ プレフィックスはプレビュー時にうるさいので sed で除去。
function fzf-src() {
    local selected_dir=$(ghq list -p \
        | sed "s|^${HOME}/src/||" \
        | fzf-tmux -p -w80% \
            --query "$LBUFFER" \
            --prompt="Repo >" \
            --preview "lsd -1A --group-directories-first --color=always --icon=always {}")
    if [[ -n "$selected_dir" ]]; then
        BUFFER="cd $(ghq root)/${selected_dir}"
        zle accept-line
    fi
    zle clear-screen
}
zle -N fzf-src
# 実際のキーバインドは ^/
bindkey '^_' fzf-src

function select-history() {
    BUFFER=$(history -n -r 1 \
        | awk '!a[$0]++' \
        | fzf-tmux -p -w80% -e --no-sort +m \
            --query "$LBUFFER" \
            --prompt="History > " \
        | sed 's/\\n/\n/g')
    CURSOR=$#BUFFER
}
zle -N select-history
bindkey '^r' select-history

function gh-create-and-cd() {
    local repo_name=$1
    if [[ -z "$repo_name" ]]; then
        echo "Usage: ghcc <repo_name> [options]"
        return 1
    fi
    shift

    local opts=("$@")
    if (( ${#opts[@]} == 0 )); then
        opts=(--private)
    fi

    local repo_url
    repo_url=$(gh repo create "$repo_name" "${opts[@]}") || return 1

    ghq get "${repo_url:-$repo_name}" || return 1

    local repo_path
    repo_path=$(ghq list -p "$repo_name" | head -n 1)
    [[ -n "$repo_path" ]] && cd "$repo_path"
}

function fzf-kill() {
    local pids
    pids=$(ps aux | fzf-tmux -p -w80% -e | awk '{print $2}')
    [[ -n "$pids" ]] && echo "$pids" | xargs kill
}
