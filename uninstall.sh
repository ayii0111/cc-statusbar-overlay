#!/bin/bash
SETTINGS="$HOME/.claude/settings.json"
CC_PAGE="$HOME/.claude/cc-page"
CAPTURE="$CC_PAGE/capture.sh"
PLIST="$HOME/Library/LaunchAgents/com.cc-statusbar-overlay.plist"

echo "=== cc-statusbar-overlay uninstaller ==="

# ── 1. Stop and remove LaunchAgent ───────────────────────────────────────────
if [ -f "$PLIST" ]; then
    launchctl unload "$PLIST" 2>/dev/null || true
    rm -f "$PLIST"
    echo "  ✓ LaunchAgent removed"
fi
pkill -f cc-statusbar-overlay 2>/dev/null || true

# ── 2. Restore settings.json ─────────────────────────────────────────────────
python3 - "$SETTINGS" "$CC_PAGE" "$CAPTURE" <<'PY'
import json, sys, os

settings_path, cc_page, capture = sys.argv[1], sys.argv[2], sys.argv[3]
prev_file = os.path.join(cc_page, "prev-statusline-cmd")

if not os.path.exists(settings_path):
    sys.exit(0)

d = json.load(open(settings_path))
current_cmd = d.get("statusLine", {}).get("command", "")

# 只在 statusLine 確實是我們的 capture hook 時才修改
if capture not in current_cmd:
    print("  ✓ statusLine was not ours — left unchanged")
    sys.exit(0)

prev = open(prev_file).read().strip() if os.path.exists(prev_file) else ""
if prev:
    d["statusLine"] = {"type": "command", "command": prev, "refreshInterval": 1}
    print(f"  ✓ Restored previous statusLine: {prev}")
else:
    print("  ⚠️  No previous statusLine to restore — leaving settings.json unchanged.")
    print("     If you had a statusLine before installing, re-add it manually.")
    sys.exit(0)

json.dump(d, open(settings_path, "w"), indent=2)
PY

# ── 3. Clean up ───────────────────────────────────────────────────────────────
rm -f "$CC_PAGE/capture.sh" "$CC_PAGE/last-statusline.json" "$CC_PAGE/prev-statusline-cmd"
rm -rf "$HOME/.local/share/cc-statusbar-overlay"
echo "  ✓ Files removed"

echo ""
echo "Done. Restart your Claude Code CLI sessions to pick up the settings change."
