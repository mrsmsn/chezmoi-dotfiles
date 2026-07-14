autoload -Uz compinit && compinit

eval "$(starship init zsh)"

## direnv (starship の後でなければ precmd フック順序が崩れる)
eval "$(direnv hook zsh)"
