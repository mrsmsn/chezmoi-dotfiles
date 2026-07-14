export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin
export GPG_TTY=$(tty)
export EDITOR=nvim

## fzf
export FZF_DEFAULT_OPTS="--reverse --border"
export FZF_CTRL_T_COMMAND='rg --files --hidden --follow --glob "!.git/*"'
export FZF_CTRL_T_OPTS='--preview "bat --color=always --style=header,grid --line-range :100 {}"'
## FIXME: 下記の環境変数を設定しても fzf-tmux 側にデフォルトとして渡されないため、
##        各コマンド呼び出しで "fzf-tmux -p -w80%" を直書きしている。要解決。
# export FZF_TMUX=1
export FZF_TMUX_OPTS='-p80%,60%'

## history
export HISTFILE="$HOME/.zsh_history"
export HISTSIZE=1000
export SAVEHIST=100000
setopt hist_ignore_dups
setopt EXTENDED_HISTORY

[[ -f "$HOME/.local/bin/env" ]] && source "$HOME/.local/bin/env"
