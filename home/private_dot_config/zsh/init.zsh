## 補完
autoload -Uz compinit && compinit

## prompt
eval "$(starship init zsh)"

## direnv (starship の後でなければ precmd フック順序が崩れる)
eval "$(direnv hook zsh)"
