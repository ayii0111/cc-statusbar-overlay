# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 建置

```bash
./build.sh
# 等同於：swiftc overlay.swift -framework Cocoa -o cc-statusbar-overlay
```

## 架構

單檔 Swift 程式（`overlay.swift`），編譯為獨立執行檔，無任何依賴。

**用途**：在 Claude 桌面版 toolbar 區域浮貼一個透明 overlay，顯示 Claude Code 的 rate limit 使用率。

**資料流**：
- 讀取 `~/.claude/cc-page/rl-5h.hiwat` 和 `~/.claude/cc-page/rl-7d.hiwat`（由外部的 `statusline-capture.sh` 維護的高水位檔）
- 格式：`<pct> <resets_at_unix_timestamp>`
- Fallback：`~/.claude/cc-page/last-statusline.json`（`rate_limits` 欄位）

**定位邏輯**：
- 透過 `CGWindowListCopyWindowInfo` 找到 Claude 視窗的螢幕位置
- 只在 Claude（bundle id `com.anthropic.claudefordesktop`）為最前景 app 時顯示
- `RIGHT_EDGE_OFFSET = 230`：overlay 右緣距 Claude 視窗右緣的距離，對準 toolbar 中的 Sonnet 文字左側；Claude UI 改版時調整此常數

**Debug 模式**：建立 `~/.claude/cc-page/overlay-debug` 檔案即啟動；log 寫入 `~/.claude/cc-page/overlay-debug.log`。刪除該檔案即關閉。
