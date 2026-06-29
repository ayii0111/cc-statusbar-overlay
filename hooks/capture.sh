#!/bin/bash
# cc-statusbar-overlay capture hook
# Saves the Claude Code statusLine JSON, then forwards to the previous statusLine command if any.
in=$(cat)
dir="$HOME/.claude/cc-page"
mkdir -p "$dir" 2>/dev/null
printf '%s' "$in" > "$dir/last-statusline.json" 2>/dev/null

prev="$dir/prev-statusline-cmd"
if [ -f "$prev" ]; then
    cmd=$(cat "$prev")
    [ -n "$cmd" ] && printf '%s' "$in" | eval "$cmd"
fi
