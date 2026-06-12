#!/usr/bin/env bash
# tmux の pane-border-format から呼ばれ、starship 風 powerline を出力する。
# 使い方: pane-border.sh <os_icon> <pane_path> <pane_command> <pane_active 0|1>
set -eu

os_icon=${1:-}
pane_path=${2:-$HOME}
pane_cmd=${3:-}
pane_active=${4:-0}

# 先頭フェード ░▒▓ は境界線 (一律 #a3aed2) に溶け込ませるため両状態で固定。
c_icon='#a3aed2' fg_icon='#090c0c'
# 残りのセグメントは starship.toml.tmpl と同じパレット。非アクティブはグレーに落とす。
if [ "$pane_active" = "1" ]; then
  c_dir='#769ff0' c_git='#394260' c_cmd='#212736'
  fg_dir='#e3e5e5' fg_seg='#769ff0'
else
  c_dir='#45475a' c_git='#313244' c_cmd='#1e1e2e'
  fg_dir='#9399b2' fg_seg='#7f849c'
fi

if [ "$pane_path" = "$HOME" ]; then
  dir='~'
else
  dir="…/$(basename "$pane_path")"
fi

branch=$(git -C "$pane_path" branch --show-current 2>/dev/null || true)

out="#[fg=${c_icon},bg=default]░▒▓"
out+="#[fg=${fg_icon},bg=${c_icon}] ${os_icon} "
out+="#[fg=${c_icon},bg=${c_dir}]"
out+="#[fg=${fg_dir},bg=${c_dir}] ${dir} "
if [ -n "$branch" ]; then
  out+="#[fg=${c_dir},bg=${c_git}]"
  out+="#[fg=${fg_seg},bg=${c_git}]  ${branch} "
  out+="#[fg=${c_git},bg=${c_cmd}]"
else
  out+="#[fg=${c_dir},bg=${c_cmd}]"
fi
out+="#[fg=${fg_seg},bg=${c_cmd}] ${pane_cmd} "
out+="#[fg=${c_cmd},bg=default]#[default]"
printf '%s' "$out"
