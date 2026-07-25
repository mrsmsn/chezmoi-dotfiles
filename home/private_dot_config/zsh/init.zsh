autoload -Uz compinit && compinit

eval "$(starship init zsh)"

## direnv (starship の後でなければ precmd フック順序が崩れる)
eval "$(direnv hook zsh)"

## プロンプト間の空行 (starship の add_newline 相当)。
## add_newline = true だと起動直後の最初のプロンプトの上にも空行が出るため、
## starship 側は false にして初回だけスキップする precmd で入れる。
## direnv より後に登録し、direnv のメッセージ出力後 (プロンプト直上) に空行を置く。
__blank_line_precmd() {
    [[ -n $__blank_line_done ]] && print
    __blank_line_done=1
}
precmd_functions+=(__blank_line_precmd)

## ghostty の shell integration は ghostty が直接 spawn したシェルにしか自動注入されない。
## herdr ペイン内の zsh でも OSC 133 プロンプトマークを出し、^L を
## 「画面内容を scrollback へ退避してからクリア」に統一するため手動で source する
## (マーク無しだと libghostty-vt の ED 2 が退避なしの破壊的消去になる)。
## スクリプト側に再入ガードがあるため ghostty 直下での二重 source は無害。
if [[ -n $GHOSTTY_RESOURCES_DIR ]]; then
    source "$GHOSTTY_RESOURCES_DIR"/shell-integration/zsh/ghostty-integration
fi
