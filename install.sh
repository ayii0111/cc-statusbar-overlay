#!/bin/bash
set -e

REPO_URL="https://github.com/ayii0111/cc-statusbar-overlay"
INSTALL_DIR="$HOME/.local/share/cc-statusbar-overlay"
SETTINGS="$HOME/.claude/settings.json"
CC_PAGE="$HOME/.claude/cc-page"
CAPTURE="$CC_PAGE/capture.sh"
PLIST="$HOME/Library/LaunchAgents/com.cc-statusbar-overlay.plist"

# ── 若由 curl | bash 執行，先 clone repo ─────────────────────────────────────
REPO="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)" || REPO=""
if [ ! -f "$REPO/overlay.swift" ]; then
    echo "→ Cloning repository to $INSTALL_DIR..."
    rm -rf "$INSTALL_DIR"
    git clone "$REPO_URL" "$INSTALL_DIR"
    exec bash "$INSTALL_DIR/install.sh"
fi

BINARY="$REPO/cc-statusbar-overlay"

echo "=== cc-statusbar-overlay installer ==="

# ── 1. Build ──────────────────────────────────────────────────────────────────
echo "→ Building..."
swiftc "$REPO/overlay.swift" -framework Cocoa -o "$BINARY"
echo "  ✓ Built: $BINARY"

# ── 2. Install capture hook ───────────────────────────────────────────────────
mkdir -p "$CC_PAGE"
cp "$REPO/hooks/capture.sh" "$CAPTURE"
chmod +x "$CAPTURE"
echo "  ✓ Capture hook installed: $CAPTURE"

# ── 3. Wire into settings.json ────────────────────────────────────────────────
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"

python3 - "$SETTINGS" "$CAPTURE" "$CC_PAGE" <<'PY'
import json, sys, os

settings_path, capture, cc_page = sys.argv[1], sys.argv[2], sys.argv[3]
prev_file = os.path.join(cc_page, "prev-statusline-cmd")

d = json.load(open(settings_path))
existing = d.get("statusLine", {}).get("command", "")

if capture in existing:
    # 已安裝，但若 prev-statusline-cmd 遺失就不做任何事（避免下次 uninstall 清空 statusLine）
    if not os.path.exists(prev_file):
        print("  ✓ statusLine already wired (prev-statusline-cmd missing — nothing to recover)")
    else:
        print("  ✓ statusLine already wired (no change)")
    sys.exit(0)

if existing:
    open(prev_file, "w").write(existing)
    print(f"  ✓ Saved previous statusLine: {existing}")
else:
    try: os.remove(prev_file)
    except FileNotFoundError: pass

d["statusLine"] = {
    "type": "command",
    "command": f"bash {capture}",
    "refreshInterval": 1
}
json.dump(d, open(settings_path, "w"), indent=2)
print("  ✓ statusLine set to capture hook")
PY

# ── 4. LaunchAgent ────────────────────────────────────────────────────────────
cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.cc-statusbar-overlay</string>
    <key>ProgramArguments</key>
    <array>
        <string>$BINARY</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
PLIST

launchctl unload "$PLIST" 2>/dev/null || true
launchctl load "$PLIST"
echo "  ✓ LaunchAgent installed (auto-starts on login)"

echo ""
echo "Done. Bring Claude desktop to the foreground to see the overlay."
echo "To remove: curl -fsSL $REPO_URL/raw/main/uninstall.sh | bash"
