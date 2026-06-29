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
