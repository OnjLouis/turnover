// SPDX-License-Identifier: GPL-3.0-or-later
// axsiblings <bundle-id>: follows AXNextContentSibling from the first AXSectionList, scrolling each into view.
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
func text(_ e: AXUIElement, _ d: Int = 0) -> [String] {
    if d > 8 { return [] }
    var out: [String] = []
    let role = attr(e, kAXRoleAttribute) as? String ?? ""
    let desc = attr(e, kAXDescriptionAttribute) as? String ?? "", title = attr(e, kAXTitleAttribute) as? String ?? "", val = attr(e, kAXValueAttribute) as? String ?? ""
    if role == "AXHeading" || role == "AXButton" || role == "AXStaticText" { let t = [title, desc, val].first { !$0.isEmpty } ?? ""; if !t.isEmpty { out.append("\(role.dropFirst(2)): \(t.prefix(70))") }; if role == "AXButton" { return out } }
    for k in (attr(e, kAXChildrenAttribute) as? [AXUIElement]) ?? [] { out += text(k, d + 1) }
    return out
}
let ax = AXUIElementCreateApplication(app.processIdentifier)
guard let w = (attr(ax, kAXWindowsAttribute) as? [AXUIElement])?.first, var s = first(w, 0) else { print("none"); exit(1) }
for i in 0..<(Int(a.count > 2 ? a[2] : "12") ?? 12) {
    let r = AXUIElementPerformAction(s, "AXScrollToVisible" as CFString)
    usleep(600_000)
    let kids = (attr(s, kAXChildrenAttribute) as? [AXUIElement]) ?? []
    print("section \(i) desc=\"\(attr(s, kAXDescriptionAttribute) as? String ?? "")\" scroll=\(r.rawValue) children=\(kids.count)")
    for t in text(s).prefix(8) { print("    \(t)") }
    guard let n = attr(s, "AXNextContentSibling") else { print("end"); break }
    s = n as! AXUIElement
}
