## ^W (backward-kill-word) の単語境界を厳しめに: `/` `_` `-` `.` の 4 文字を
backward-kill-subword() {
  local WORDCHARS=${WORDCHARS//[\/._-]}
  zle backward-kill-word
}
zle -N backward-kill-subword
bindkey '^W' backward-kill-subword
