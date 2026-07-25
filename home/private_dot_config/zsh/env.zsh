# SSH ログインでは LANG が渡らず locale が C になり、less が UTF-8 をバイナリ表示するため明示する
export LANG=en_US.UTF-8

export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin
export GPG_TTY=$(tty)
export EDITOR=nvim

## fzf
export FZF_DEFAULT_OPTS="--reverse --border"
export FZF_CTRL_T_COMMAND='rg --files --hidden --follow --glob "!.git/*"'
export FZF_CTRL_T_OPTS='--preview "bat --color=always --style=header,grid --line-range :100 {}"'

## history
export HISTFILE="$HOME/.zsh_history"
export HISTSIZE=1000
export SAVEHIST=100000
setopt hist_ignore_dups
setopt EXTENDED_HISTORY

[[ -f "$HOME/.local/bin/env" ]] && source "$HOME/.local/bin/env"
