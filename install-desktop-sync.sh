#!/bin/bash
set -e

# ── Desktop 額度同步（選用，非預設安裝的一部分）──────────────────────────────
# 用被動 TLS 側錄拿到 Claude 桌面 App 真實對話回應裡的 anthropic-ratelimit-unified-*
# header，寫進與 hooks/capture.sh 相同的高水位目錄，讓桌面端單獨開啟時 overlay
# 額度也能更新。細節見 README「Desktop 額度同步」一節。
#
# 注意：這會用 launchctl setenv 把 HTTPS_PROXY/HTTP_PROXY 設成全系統登入層級，
# 影響所有從 launchd 啟動的 App（不只 Claude）。mitmdump 由 LaunchAgent 以
# KeepAlive 常駐，若它意外掛掉，所有依賴這兩個環境變數的網路連線會斷線直到
# 服務自動重啟或你手動 unset。

REPO="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
CC_PAGE="$HOME/.claude/cc-page"
MITM_CONFDIR="$HOME/.mitmproxy"
CAPTURE_SCRIPT="$CC_PAGE/capture-desktop.py"
PLIST="$HOME/Library/LaunchAgents/com.cc-statusbar-overlay.mitmproxy.plist"
PROXY_PORT=8080

echo "=== cc-statusbar-overlay: Desktop 額度同步安裝 ==="

# ── 1. mitmproxy ──────────────────────────────────────────────────────────────
if ! command -v mitmdump >/dev/null 2>&1; then
    echo "→ 安裝 mitmproxy（brew）..."
    brew install mitmproxy
fi
MITMDUMP_BIN="$(command -v mitmdump)"
echo "  ✓ mitmdump: $MITMDUMP_BIN"

# ── 2. 產生 CA（跑一下立刻關掉，只為了讓 mitmproxy 產生憑證檔）─────────────────
mkdir -p "$MITM_CONFDIR"
if [ ! -f "$MITM_CONFDIR/mitmproxy-ca-cert.pem" ]; then
    echo "→ 產生 mitmproxy CA..."
    ("$MITMDUMP_BIN" --set confdir="$MITM_CONFDIR" -q &)
    sleep 3
    pkill -f "mitmdump --set confdir=$MITM_CONFDIR" 2>/dev/null || true
fi
echo "  ✓ CA: $MITM_CONFDIR/mitmproxy-ca-cert.pem"

# ── 3. 信任 CA（登入鑰匙圈）────────────────────────────────────────────────────
security add-trusted-cert -d -r trustRoot -k "$HOME/Library/Keychains/login.keychain-db" \
    "$MITM_CONFDIR/mitmproxy-ca-cert.pem"
echo "  ✓ CA 已加入登入鑰匙圈信任清單"

# ── 4. 安裝側錄腳本 ─────────────────────────────────────────────────────────────
mkdir -p "$CC_PAGE"
cp "$REPO/hooks/capture-desktop.py" "$CAPTURE_SCRIPT"
echo "  ✓ 側錄腳本安裝：$CAPTURE_SCRIPT"

# ── 5. LaunchAgent：常駐 mitmdump + 設定全系統代理環境變數 ────────────────────
cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.cc-statusbar-overlay.mitmproxy</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/sh</string>
        <string>-c</string>
        <string>launchctl setenv HTTPS_PROXY http://127.0.0.1:$PROXY_PORT; launchctl setenv HTTP_PROXY http://127.0.0.1:$PROXY_PORT; exec "$MITMDUMP_BIN" --set confdir="$MITM_CONFDIR" -p $PROXY_PORT -s "$CAPTURE_SCRIPT" -q</string>
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
echo "  ✓ LaunchAgent 已安裝並啟動（開機自動常駐）"

echo ""
echo "完成。請完全結束 Claude App（Cmd+Q）後重新開啟，讓它套用新的代理環境變數。"
echo "之後只要桌面端有真實對話發生，overlay 額度就會跟著更新。"
echo "移除：$REPO/uninstall-desktop-sync.sh"
