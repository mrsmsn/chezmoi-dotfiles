alias ll='lsd -al --group-directories-first'
alias l='lsd -a1 --group-directories-first'

alias vim='nvim'
alias vi='nvim'

alias gb='open $(git config --get remote.origin.url | sed -e "s|git@github.com:|https://github.com/|" -e "s|\.git$||")'
alias ghcc='gh-create-and-cd'

alias lg='lazygit'
alias cal='jpcal -3'
alias fk='fzf-kill'
alias docker='podman'
alias chrome='open -a google\ chrome'
alias cmu='chezmoi update'

alias ccc='claude -c'
alias ccr='claude -r'
