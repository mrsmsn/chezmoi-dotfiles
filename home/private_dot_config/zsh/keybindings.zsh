## exec 環境の EDITOR に "vi" を含む値 (nvim 等) があると ZLE が viins で起動するため、
## emacs キーマップを明示する。ここより後の bindkey はすべて emacs キーマップに入る。
bindkey -e

## ^W (backward-kill-word) の単語境界を厳しめに: `/` `_` `-` `.` の 4 文字を
backward-kill-subword() {
  local WORDCHARS=${WORDCHARS//[\/._-]}
  zle backward-kill-word
}
zle -N backward-kill-subword
bindkey '^W' backward-kill-subword
