# cc-statusbar-overlay

A floating overlay for the **Claude desktop app** that displays your Claude Code rate-limit usage directly in the toolbar — no terminal window needed.

```
5h ▰▰▱▱▱ 42% ↺1h23m   7d ▰▰▱▱▱ 38% ↺2d5h
```

The overlay appears only when Claude is the frontmost app, and hides automatically when you switch away.

## Prerequisites

| Requirement | Notes |
|---|---|
| macOS | Tested on macOS 14+. Requires screen recording or Accessibility permission for window tracking. |
| Claude desktop app | [claude.ai/download](https://claude.ai/download) |
| Claude Code CLI | Installed and has run at least once |
| Xcode Command Line Tools | `xcode-select --install` |

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/ayii0111/cc-statusbar-overlay/main/install.sh | bash
```

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/ayii0111/cc-statusbar-overlay/main/uninstall.sh | bash
```

The installer does three things:

1. **Clones** the repo to `~/.local/share/cc-statusbar-overlay` and **builds** the binary with `swiftc`
2. **Installs a LaunchAgent** so the overlay starts automatically on login
3. **Installs a `statusLine` hook** into `~/.claude/settings.json` — if you already have a statusLine configured (e.g. coralline), it is preserved and chained automatically

The uninstaller reverses all three steps and restores your previous statusLine if one existed.

## How it works

Claude Code's `statusLine` hook fires on every render and pipes a JSON blob to a shell script. The hook saves this JSON to `~/.claude/cc-page/last-statusline.json`. The overlay reads that file every second and renders the `rate_limits.five_hour` and `rate_limits.seven_day` fields into the bar.

## Desktop 額度同步（選用）

`statusLine` 是 CLI 專屬機制，桌面 App 走的是另一條 GUI/IPC 渲染路徑，不會觸發它——所以**只開桌面 App、沒開任何 CLI session 時，overlay 額度不會更新**。

這是選用的擴充：透過本機 mitmproxy 被動側錄桌面 App 對 `/v1/messages` 的真實回應（不主動發送任何額外請求，不消耗額度），從 response header 的 `anthropic-ratelimit-unified-*` 換算後寫進與 `capture.sh` 相同的高水位目錄（`~/.claude/cc-page/limit-5h.d` / `limit-7d.d`），CLI 與桌面端因此共用同一套「取最新/最大值」合併邏輯，誰先更新都不會互相覆蓋。

```bash
./install-desktop-sync.sh    # 安裝
./uninstall-desktop-sync.sh  # 移除
```

**這會做的事，安裝前請先了解：**

1. 安裝 mitmproxy（`brew install mitmproxy`）
2. 把 mitmproxy 的自簽 CA 加入 macOS 登入鑰匙圈信任清單（影響整台機器的 TLS 信任鏈）
3. 用 `launchctl setenv HTTPS_PROXY/HTTP_PROXY` 把代理設成**全系統登入層級**——不只 Claude App，所有從 launchd 啟動的 App 與許多 CLI 工具都會走這個代理
4. 常駐一個 mitmdump LaunchAgent（`KeepAlive` 自動重啟）；但若它意外掛掉或未啟動，依賴這兩個環境變數的網路連線會斷線直到服務重啟或你手動 `launchctl unsetenv`

安裝後需完全結束 Claude App（Cmd+Q）再重開，才會套用代理設定。

## Configuration

The overlay positions itself relative to the Claude window's right edge. If a Claude UI update shifts the toolbar layout, adjust this constant in `overlay.swift` and rebuild:

```swift
let RIGHT_EDGE_OFFSET: CGFloat = 230  // distance from Claude window's right edge
```

## Debug

Create the flag file to enable logging:

```bash
touch ~/.claude/cc-page/overlay-debug
tail -f ~/.claude/cc-page/overlay-debug.log
```

Delete it to disable:

```bash
rm ~/.claude/cc-page/overlay-debug
```

## Uninstall

```bash
launchctl unload ~/Library/LaunchAgents/com.cc-statusbar-overlay.plist
rm ~/Library/LaunchAgents/com.cc-statusbar-overlay.plist
```

Then remove the `statusLine` entry from `~/.claude/settings.json` if it was added by the installer.
