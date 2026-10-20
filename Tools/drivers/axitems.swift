// SPDX-License-Identifier: GPL-3.0-or-later
// axitems <bundle-id> <section-index>: walks a section's items by AXNextContentSibling.
import Foundation
import AppKit
import ApplicationServices
setvbuf(stdout, nil, _IONBF, 0)
let a = CommandLine.arguments
guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: a[1]).first else { exit(1) }
func attr(_ e: AXUIElement, _ k: String) -> AnyObject? { var v: AnyObject?; return AXUIElementCopyAttributeValue(e, k as CFString, &v) == .success ? v : nil }
func first(_ e: AXUIElement, _ d: Int) -> AXUIElement? {
    if (attr(e, kAXSubroleAttribute) as? String) == "AXSectionList" { return e }
    if d > 30 { return nil }
    for k in (attr(e, kAXChildrenAttribute) as? [AXUIElement]) ?? [] { if let f = first(k, d + 1) { return f } }
    return nil
}
func label(_ e: AXUIElement, _ d: Int = 0) -> String {
    if d > 6 { return "" }
    let role = attr(e, kAXRoleAttribute) as? String ?? ""
    if role == "AXButton" || role == "AXHeading" { return (attr(e, kAXDescriptionAttribute) as? String) ?? (attr(e, kAXTitleAttribute) as? String) ?? "" }
    if let t = attr(e, kAXTitleAttribute) as? String, !t.isEmpty { return t }
    for k in (attr(e, kAXChildrenAttribute) as? [AXUIElement]) ?? [] { let l = label(k, d + 1); if !l.isEmpty { return l } }
    return ""
}
let ax = AXUIElementCreateApplication(app.processIdentifier)
guard let w = (attr(ax, kAXWindowsAttribute) as? [AXUIElement])?.first, var s = first(w, 0) else { exit(1) }
for _ in 0..<(Int(a[2]) ?? 0) { s = attr(s, "AXNextContentSibling") as! AXUIElement }
_ = AXUIElementPerformAction(s, "AXScrollToVisible" as CFString); usleep(500_000)
print("section: \(attr(s, kAXDescriptionAttribute) as? String ?? "")")
let items = ((attr(s, kAXChildrenAttribute) as? [AXUIElement]) ?? []).filter { ((attr($0, kAXIdentifierAttribute) as? String) ?? "").contains("shelfItem") }
guard var it = items.first else { print("no items"); exit(0) }
for i in 0..<40 {
    print("  \(i): idx=\(attr(it, "AXIndex") as? Int ?? -1) \(label(it).prefix(90))")
    guard let n = attr(it, "AXNextContentSibling") else { print("  end"); break }
    it = n as! AXUIElement
}
if let last = attr(items.first!, "AXLastContentSibling") { print("last: idx=\(attr(last as! AXUIElement, "AXIndex") as? Int ?? -1) \(label(last as! AXUIElement).prefix(80))") }
