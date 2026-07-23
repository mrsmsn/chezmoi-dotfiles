# fzf を前面表示する。tmux 内は popup、それ以外 (herdr 内含む) は素の fzf。
# herdr 0.7.1 のプラグインペインは placement 指定に関わらずタブ全域に
# 描画される (ペインローカルな float は不可) ため、ペイン内で完結する
# 素の fzf を採用している。
function fzf-float() {
    if [[ -n "$TMUX" ]]; then
        fzf-tmux -p -w80% "$@"
    else
        fzf "$@"
    fi
}

### ghq.root を複数設定している場合に対応するため -p を使用。
### ${HOME}/src/ プレフィックスはプレビュー時にうるさいので sed で除去。
function fzf-src() {
    local selected_dir=$(ghq list -p \
        | sed "s|^${HOME}/src/||" \
        | fzf-float \
            --query "$LBUFFER" \
            --prompt="Repo >" \
            --preview "lsd -1A --group-directories-first --color=always --icon=always $(ghq root)/{}")
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
        | fzf-float -e --no-sort +m \
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
    pids=$(ps aux | fzf-float -e | awk '{print $2}')
    [[ -n "$pids" ]] && echo "$pids" | xargs kill
}
