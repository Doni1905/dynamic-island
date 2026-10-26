// island_probe.swift - READ-ONLY feasibility probe for Dynamic Island notification capture.
// Prints: macOS version, whether Accessibility trust is granted, and the STRUCTURE of the
// Notification Center UI (roles, subroles, counts, text LENGTHS only).
// Never: prints notification text, moves/hides/changes any window or setting, writes files,
// or uses the network. Output stays in your Terminal; you choose what to paste back.
//
// Run:   swift tools/island_probe.swift     (needs Xcode Command Line Tools: xcode-select --install)
// macOS 27: the permission formerly called "Accessibility" is now "Device Control and Data Access"
//   (System Settings > Privacy & Security). Enable it for Terminal, then re-run.
// While it watches (60s), from a SECOND Terminal tab fire a harmless banner:
//   osascript -e 'display notification "probe test body" with title "IslandProbe" subtitle "test"'

import Cocoa
import ApplicationServices

func ax<T>(_ el: AXUIElement, _ attr: String) -> T? {
    var v: CFTypeRef?
    guard AXUIElementCopyAttributeValue(el, attr as CFString, &v) == .success, let v = v else { return nil }
    return v as? T
}
func settable(_ el: AXUIElement, _ attr: String) -> String {
    var flag = DarwinBoolean(false)
    guard AXUIElementIsAttributeSettable(el, attr as CFString, &flag) == .success else { return "unknown" }
    return flag.boolValue ? "true" : "false"
}

print("== island probe (read-only) ==")
print("macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)")
let trusted = AXIsProcessTrusted()
print("accessibility_trusted: \(trusted)")
if !trusted {
    print("ACTION NEEDED: System Settings > Privacy & Security > Accessibility (macOS 27: \"Device Control and Data Access\") > enable Terminal, quit and reopen Terminal, re-run.")
    exit(0)
}
guard let nc = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.notificationcenterui").first else {
    print("notification_center_process: NOT RUNNING (report this)")
    exit(0)
}
print("notification_center_process: running")
let app = AXUIElementCreateApplication(nc.processIdentifier)
var seen = Set<String>()

// Structure line: indentation = depth. Only role/subrole/counts/lengths; never values.
func dump(_ el: AXUIElement, _ depth: Int, _ lines: inout [String]) {
    if depth > 10 || lines.count > 80 { return }
    let role: String = ax(el, kAXRoleAttribute) ?? "?"
    let sub: String = ax(el, kAXSubroleAttribute) ?? "-"
    var extra = ""
    if role == kAXStaticTextRole as String {
        let s: String = ax(el, kAXValueAttribute) ?? ""
        extra = " text_len=\(s.count)"
    }
    if depth == 0 { extra += " pos_settable=\(settable(el, kAXPositionAttribute))" }
    var acts: CFArray?
    AXUIElementCopyActionNames(el, &acts)
    let actCount = (acts as? [String])?.count ?? 0
    lines.append(String(repeating: "  ", count: depth) + "\(role)/\(sub) actions=\(actCount)" + extra)
    for c in (ax(el, kAXChildrenAttribute) as [AXUIElement]?) ?? [] { dump(c, depth + 1, &lines) }
}

func scan(_ label: String) {
    let wins: [AXUIElement] = ax(app, kAXWindowsAttribute) ?? []
    var sig = "\(wins.count)"
    var blocks: [String] = []
    for w in wins {
        var lines: [String] = []
        dump(w, 0, &lines)
        sig += lines.joined()
        blocks.append(lines.joined(separator: "\n"))
    }
    if seen.contains(sig) { return }
    seen.insert(sig)
    print("[\(label)] nc_windows=\(wins.count)")
    for (i, b) in blocks.enumerated() { print("-- window \(i) --\n\(b)") }
}

scan("t0")
print("watching 60s; fire the osascript test banner now...")
let end = Date().addingTimeInterval(60)
var t = 0
while Date() < end { Thread.sleep(forTimeInterval: 1); t += 1; scan("t\(t)s") }
print("== probe done. Paste everything above back. It contains no notification text, only structure and lengths. ==")
