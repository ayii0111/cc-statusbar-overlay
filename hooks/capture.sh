#!/bin/bash
# cc-statusbar-overlay capture hook
# Saves the Claude Code statusLine JSON, then forwards to the previous statusLine command if any.
in=$(cat)
dir="$HOME/.claude/cc-page"
mkdir -p "$dir" 2>/dev/null
printf '%s' "$in" > "$dir/last-statusline.json" 2>/dev/null

# 跨 session 高水位同步（做法對齊 coralline app/main.swift 的 rl_sample）：
# 用量在同一個 reset 窗口內只會往上升，把每次 render 看到的值記一筆，
# 之後取「目前窗口內看過的最大值」即可，這樣某個久未更新的閒置 session
# 剛好搶先寫入 last-statusline.json 時，不會把畫面蓋回舊的低值。
# 目錄內每筆是一個原子建立的 mkdir，同一秒多個 session 並發寫入也不會互相覆蓋。
rl_sample() {  # $1=store dir  $2=pct  $3=resets_at(epoch)  $4=max secs ahead（天花板）
    [ -n "$2" ] && [ -n "$3" ] && [ "$2" != "null" ] && [ "$3" != "null" ] || return 0
    # 拒絕不合理的未來 resets_at（sentinel/壞資料）：這種假窗口一旦寫入，因為
    # reset 值最大會永久霸佔高水位、把 store 徹底污染（coralline #32 踩過的坑）
    [ "$3" -le "$(( NOW + $4 ))" ] 2>/dev/null || return 0
    mkdir -p "$1" 2>/dev/null
    printf -v r '%010d' "$3" 2>/dev/null || return 0
    printf -v p '%07.3f' "$2" 2>/dev/null || return 0
    mkdir "$1/${r}_${p}" 2>/dev/null
    return 0
}

if command -v jq >/dev/null 2>&1; then
    NOW=$(date +%s)
    vals=$(printf '%s' "$in" | jq -r '[.rate_limits.five_hour.used_percentage, .rate_limits.five_hour.resets_at, .rate_limits.seven_day.used_percentage, .rate_limits.seven_day.resets_at] | @tsv' 2>/dev/null)
    IFS=$'\t' read -r p5 r5 p7 r7 <<< "$vals"
    rl_sample "$dir/limit-5h.d" "$p5" "$r5" "$(( 6 * 3600 ))"    # 5h 窗口，抓 6h 當時鐘誤差緩衝
    rl_sample "$dir/limit-7d.d" "$p7" "$r7" "$(( 8 * 86400 ))"   # 7d 窗口，抓 8d 當時鐘誤差緩衝
fi

prev="$dir/prev-statusline-cmd"
if [ -f "$prev" ]; then
    cmd=$(cat "$prev")
    [ -n "$cmd" ] && printf '%s' "$in" | eval "$cmd"
fi
