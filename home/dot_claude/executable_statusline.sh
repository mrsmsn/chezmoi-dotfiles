#!/usr/bin/env bash
# Claude Code statusLine (2 行)。
# 参考: https://techblog.cartaholdings.co.jp/entry/customize-claude-statusline
set -euo pipefail

# jq 1 回で全項目を取り出す (応答ごとに走るので起動コストを抑える)。
# 欠損しうる項目は "-" センチネル (空文字だと @tsv の連続タブを read が潰して列ズレする)。
line=$(jq -r '[
  (.model.display_name // "?"),
  (.effort.level // "-"),
  (.context_window.used_percentage | if . == null then "-" else round end),
  (.rate_limits.five_hour.used_percentage | if . == null then "-" else round end),
  (.rate_limits.seven_day.used_percentage | if . == null then "-" else round end),
  (.cost.total_duration_ms // 0 | floor),
  (.cost.total_api_duration_ms // 0 | floor)
] | @tsv')
IFS=$'\t' read -r model effort ctx five seven dur api <<< "$line"

render_bar() {
    local total=15 filled=$(( $1 * 15 / 100 )) bar=""
    [ "$filled" -gt "$total" ] && filled=$total
    local i
    for (( i = 0; i < filled; i++ )); do bar+="█"; done
    for (( i = filled; i < total; i++ )); do bar+="░"; done
    printf '%s' "$bar"
}

fmt_dur() {
    local s=$(( $1 / 1000 )) h m
    h=$(( s / 3600 ))
    m=$(( s % 3600 / 60 ))
    if [ "$h" -gt 0 ]; then
        printf '%dh%dm' "$h" "$m"
    elif [ "$m" -gt 0 ]; then
        printf '%dm' "$m"
    else
        printf '%ds' "$s"
    fi
}

# --- 1 行目: context 使用率 │ モデル (effort) │ 経過時間 (API 待ち) ---
if [ "$ctx" = "-" ]; then
    line1="🧠 $(render_bar 0) --%"
else
    line1="🧠 $(render_bar "$ctx") ${ctx}%"
fi
line1="${line1} │ 💪 ${model}"
[ "$effort" != "-" ] && line1="${line1} (${effort})"
line1="${line1} │ ⏱ $(fmt_dur "$dur") (api $(fmt_dur "$api"))"

# --- 2 行目: 5 時間枠 │ 7 日枠 (サブスクの初回応答後にのみ出る) ---
if [ "$five" != "-" ]; then
    line2="🕐 $(render_bar "$five") ${five}%"
    [ "$seven" != "-" ] && line2="${line2} │ 📅 $(render_bar "$seven") ${seven}%"
    printf '%s\n%s\n' "$line1" "$line2"
else
    printf '%s\n' "$line1"
fi
