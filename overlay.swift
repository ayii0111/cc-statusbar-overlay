import Cocoa
import Foundation

// ── Debug ─────────────────────────────────────────────────────────────────────
// 建立 ~/.claude/cc-page/overlay-debug 即啟動 debug 模式，刪除即關閉
let DEBUG_FLAG = NSHomeDirectory() + "/.claude/cc-page/overlay-debug"
let DEBUG_LOG  = NSHomeDirectory() + "/.claude/cc-page/overlay-debug.log"

func dbg(_ msg: String) {
    guard FileManager.default.fileExists(atPath: DEBUG_FLAG) else { return }
    let ts = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
    let line = "[\(ts)] \(msg)\n"
    if let data = line.data(using: .utf8) {
        if let fh = FileHandle(forWritingAtPath: DEBUG_LOG) {
            fh.seekToEndOfFile(); fh.write(data); fh.closeFile()
        } else {
            try? data.write(to: URL(fileURLWithPath: DEBUG_LOG))
        }
    }
}

// ── JSON 解析 ────────────────────────────────────────────────────────────────
// 與 coralline app/main.swift 對齊：直接讀 last-statusline.json

struct Limit { var pct: Int = 0; var resetsAt: Double = 0 }
struct Status { var fiveHour = Limit(); var sevenDay = Limit() }

let _iso = ISO8601DateFormatter()

func parseLimit(_ entry: [String: Any]?) -> Limit {
    guard let e = entry else { return Limit() }
    let pct = (e["used_percentage"] as? NSNumber)?.intValue ?? 0
    var rst: Double = 0
    if let n = e["resets_at"] as? NSNumber {
        rst = n.doubleValue                          // Unix timestamp（數字）
    } else if let s = e["resets_at"] as? String, let d = _iso.date(from: s) {
        rst = d.timeIntervalSince1970                // ISO 8601 字串（fallback）
    }
    return Limit(pct: pct, resetsAt: rst)
}

func readStatus() -> Status? {
    let path = NSHomeDirectory() + "/.claude/cc-page/last-statusline.json"
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
          let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let rl = j["rate_limits"] as? [String: Any]
    else { dbg("readStatus: 讀不到 last-statusline.json"); return nil }
    var s = Status()
    s.fiveHour = parseLimit(rl["five_hour"] as? [String: Any])
    s.sevenDay  = parseLimit(rl["seven_day"]  as? [String: Any])
    dbg("readStatus: 5h=\(s.fiveHour.pct)% rst=\(s.fiveHour.resetsAt)  7d=\(s.sevenDay.pct)% rst=\(s.sevenDay.resetsAt)")
    return s
}

func bar(_ pct: Int, width: Int = 5) -> String {
    let filled = max(0, min(width, Int(Double(pct) / 100.0 * Double(width) + 0.5)))
    return String(repeating: "▰", count: filled) + String(repeating: "▱", count: width - filled)
}

func eta(_ ts: Double) -> String {
    let secs = Int(max(0, ts - Date().timeIntervalSince1970))
    guard secs > 0 else { return "" }
    let d = secs / 86400, h = secs / 3600, m = secs / 60
    if d >= 1 { return "↺\(d)d\((secs % 86400) / 3600)h" }
    if h >= 1 { return "↺\(h)h\((secs % 3600) / 60)m" }
    return "↺\(m)m"
}

func formatStatus(_ s: Status) -> String {
    "5h \(bar(s.fiveHour.pct)) \(s.fiveHour.pct)% \(eta(s.fiveHour.resetsAt))   7d \(bar(s.sevenDay.pct)) \(s.sevenDay.pct)% \(eta(s.sevenDay.resetsAt))"
}

// ── Claude 視窗位置 ──────────────────────────────────────────────────────────

func findClaudeWindowFrame() -> CGRect? {
    let opts = CGWindowListOption([.optionOnScreenOnly, .excludeDesktopElements])
    guard let list = CGWindowListCopyWindowInfo(opts, kCGNullWindowID) as? [[String: Any]]
    else { return nil }
    for info in list {
        guard let owner = info[kCGWindowOwnerName as String] as? String,
              owner.lowercased().contains("claude"),
              let layer = info[kCGWindowLayer as String] as? Int, layer == 0,
              let b = info[kCGWindowBounds as String] as? [String: CGFloat],
              (b["Width"] ?? 0) > 200, (b["Height"] ?? 0) > 200
        else { continue }
        return CGRect(x: b["X"]!, y: b["Y"]!, width: b["Width"]!, height: b["Height"]!)
    }
    return nil
}

// ── 定位常數 ──────────────────────────────────────────────────────────────────
let TOOLBAR_H: CGFloat = 44
var OVERLAY_W: CGFloat = 260  // 動態，根據文字寬度調整
let OVERLAY_H: CGFloat = TOOLBAR_H - 6

// 右邊界距 Claude 視窗右緣的距離（涵蓋 Sonnet 文字區 + 8px 間距）
// 若 UI 改版需要調整，改這一個數字即可
let RIGHT_EDGE_OFFSET: CGFloat = 230

// ── Overlay Window ───────────────────────────────────────────────────────────

class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let panel = OverlayPanel(
    contentRect: CGRect(x: 0, y: 0, width: OVERLAY_W, height: OVERLAY_H),
    styleMask: [.borderless, .nonactivatingPanel],
    backing: .buffered,
    defer: false
)
panel.level = .floating
panel.backgroundColor = .clear
panel.isOpaque = false
panel.hasShadow = false
panel.ignoresMouseEvents = true
panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

let label = NSTextField(labelWithString: "")
label.backgroundColor = .clear
label.isBezeled = false
label.alignment = .right

let textColor = NSColor(red: 0.239, green: 0.224, blue: 0.161, alpha: 1.0)
let attrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 12, weight: .regular),
    .foregroundColor: textColor,
]
label.attributedStringValue = NSAttributedString(string: "", attributes: attrs)

let container = NSView()
container.wantsLayer = true
// Claude toolbar 底色，讓 subpixel AA 正常工作
container.layer?.backgroundColor = NSColor(red: 0.98, green: 0.976, blue: 0.961, alpha: 1.0).cgColor
container.addSubview(label)
panel.contentView = container


let CLAUDE_BUNDLE = "com.anthropic.claudefordesktop"

// ── 快取：避免不必要的重繪與 syscall ─────────────────────────────────────────
var lastFileDate: Date? = nil
var lastText: String = ""
var lastPanelFrame: CGRect = .zero

func updateOverlay() {
    // 只在 Claude Code 桌面版為最前景 app 時顯示
    let frontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "nil"
    guard frontmost == CLAUDE_BUNDLE else {
        if panel.isVisible { panel.orderOut(nil) }
        return
    }
    guard let frame = findClaudeWindowFrame() else {
        if panel.isVisible { panel.orderOut(nil) }
        return
    }

    // 只在檔案有更新時才重新解析 JSON
    let jsonPath = NSHomeDirectory() + "/.claude/cc-page/last-statusline.json"
    let fileDate = (try? FileManager.default.attributesOfItem(atPath: jsonPath))?[.modificationDate] as? Date
    if fileDate != lastFileDate, let s = readStatus() {
        lastFileDate = fileDate
        let newText = formatStatus(s)
        if newText != lastText {
            lastText = newText
            let str = NSAttributedString(string: newText, attributes: attrs)
            label.attributedStringValue = str
            OVERLAY_W = ceil(str.boundingRect(with: NSSize(width: 9999, height: 20), options: .usesLineFragmentOrigin).width) + 4
        }
    }

    // 只在位置真的變了才呼叫 setFrame
    let screenH = NSScreen.main?.frame.height ?? 900
    let claudeNSY = screenH - frame.origin.y - frame.size.height
    let rightEdge = frame.origin.x + frame.size.width - RIGHT_EDGE_OFFSET
    let ox = rightEdge - OVERLAY_W
    let oy = claudeNSY + (TOOLBAR_H - OVERLAY_H) / 2
    let newFrame = CGRect(x: ox, y: oy, width: OVERLAY_W, height: OVERLAY_H)
    if newFrame != lastPanelFrame {
        lastPanelFrame = newFrame
        panel.setFrame(newFrame, display: true)
        label.frame = CGRect(x: 0, y: (OVERLAY_H - 18) / 2, width: OVERLAY_W, height: 18)
        dbg("定位: rightEdge=\(Int(rightEdge)) ox=\(Int(ox)) w=\(Int(OVERLAY_W))")
    }

    if !panel.isVisible { panel.orderFront(nil) }
}

// ── Run Loop ─────────────────────────────────────────────────────────────────

// app 切換時立即顯示/隱藏
NSWorkspace.shared.notificationCenter.addObserver(
    forName: NSWorkspace.didActivateApplicationNotification,
    object: nil, queue: .main
) { _ in updateOverlay() }

Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in updateOverlay() }
updateOverlay()
app.run()
