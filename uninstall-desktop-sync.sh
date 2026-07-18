#!/bin/bash

CC_PAGE="$HOME/.claude/cc-page"
MITM_CONFDIR="$HOME/.mitmproxy"
CAPTURE_SCRIPT="$CC_PAGE/capture-desktop.py"
PLIST="$HOME/Library/LaunchAgents/com.cc-statusbar-overlay.mitmproxy.plist"

echo "=== cc-statusbar-overlay: Desktop 額度同步移除 ==="

if [ -f "$PLIST" ]; then
    launchctl unload "$PLIST" 2>/dev/null || true
    rm -f "$PLIST"
    echo "  ✓ LaunchAgent 已移除"
fi
pkill -f "mitmdump.*capture-desktop.py" 2>/dev/null || true

launchctl unsetenv HTTPS_PROXY
launchctl unsetenv HTTP_PROXY
echo "  ✓ 已清除全系統 HTTPS_PROXY/HTTP_PROXY"

if [ -f "$MITM_CONFDIR/mitmproxy-ca-cert.pem" ]; then
    security delete-certificate -c mitmproxy "$HOME/Library/Keychains/login.keychain-db" 2>/dev/null || true
    echo "  ✓ mitmproxy CA 已從登入鑰匙圈移除"
fi

rm -f "$CAPTURE_SCRIPT"
echo "  ✓ 側錄腳本已移除"

echo ""
echo "完成。請完全結束 Claude App 後重新開啟，讓它脫離代理設定。"
