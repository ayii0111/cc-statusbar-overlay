# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 建置

```bash
./build.sh
# 等同於：swiftc overlay.swift -framework Cocoa -o cc-statusbar-overlay
```

## 安裝 / 卸載

```bash
./install.sh    # build + LaunchAgent + statusLine hook
./uninstall.sh  # 反向還原所有步驟
```

`install.sh` 做三件事：
1. 編譯 binary
2. 將 `hooks/capture.sh` 複製到 `~/.claude/cc-page/capture.sh`，並注入 `~/.claude/settings.json` 的 `statusLine`（會儲存並串接既有的 statusLine）
3. 建立 LaunchAgent（`~/Library/LaunchAgents/com.cc-statusbar-overlay.plist`），登入時自動啟動

## 架構

單檔 Swift 程式（`overlay.swift`），編譯為獨立執行檔，無任何依賴。

**用途**：在 Claude 桌面版 toolbar 區域浮貼一個透明 overlay，顯示 Claude Code 的 rate limit 使用率。

**資料流**：
- `hooks/capture.sh` 作為 `statusLine` hook，接收 Claude Code 每次渲染時的 JSON，存入 `~/.claude/cc-page/last-statusline.json`，再串接給原有的 statusLine 指令（若有）
- `overlay.swift` 每秒讀取該 JSON 的 `rate_limits.five_hour` 與 `rate_limits.seven_day` 欄位並渲染
- 只在檔案 mtime 有變化時才重新解析（快取避免不必要的 syscall）

**定位邏輯**：
- 透過 `CGWindowListCopyWindowInfo` 找到 Claude 視窗的螢幕位置
- 只在 Claude（bundle id `com.anthropic.claudefordesktop`）為最前景 app 時顯示
- `RIGHT_EDGE_OFFSET = 230`：overlay 右緣距 Claude 視窗右緣的距離，對準 toolbar 中的 Sonnet 文字左側；Claude UI 改版時調整此常數

**Debug 模式**：建立 `~/.claude/cc-page/overlay-debug` 檔案即啟動；log 寫入 `~/.claude/cc-page/overlay-debug.log`。刪除該檔案即關閉。
