## ^W (backward-kill-word) の単語境界を厳しめに: `/` `_` `-` `.` の 4 文字を
## デフォルト WORDCHARS から落として呼ぶ。これにより
##   /etc/profiles/per-user/mosh/bin → 末尾 `bin` だけ消える
##   my-file.txt                     → `txt` → `.` → `file` → `-` → `my` の順
## ^W のみ局所変更なので M-b / M-f 等の他 widget はデフォルト挙動のまま。
backward-kill-subword() {
  local WORDCHARS=${WORDCHARS//[\/._-]}
  zle backward-kill-word
}
zle -N backward-kill-subword
bindkey '^W' backward-kill-subword
