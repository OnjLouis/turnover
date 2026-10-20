// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
import AppKit
import ApplicationServices
setvbuf(stdout, nil, _IONBF, 0)
let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.AppStore").first!
func attr(_ e: AXUIElement, _ k: String) -> AnyObject? { var v: AnyObject?; return AXUIElementCopyAttributeValue(e, k as CFString, &v) == .success ? v : nil }
func first(_ e: AXUIElement, _ d: Int, _ t: (AXUIElement) -> Bool) -> AXUIElement? {
    if t(e) { return e }; if d > 30 { return nil }
    for k in (attr(e, kAXChildrenAttribute) as? [AXUIElement]) ?? [] { if let f = first(k, d + 1, t) { return f } }
    return nil
}
let ax = AXUIElementCreateApplication(app.processIdentifier)
let w = (attr(ax, kAXWindowsAttribute) as! [AXUIElement])[0]
var s = first(w, 0) { (attr($0, kAXSubroleAttribute) as? String) == "AXSectionList" }!
var n = 0
while let next = attr(s, "AXNextContentSibling") { s = next as! AXUIElement; n += 1 }
print("last loaded section \(n): \(attr(s, kAXDescriptionAttribute) as? String ?? "")")
let last = attr(s, "AXLastContentSibling")
print("AXLastContentSibling: \(last.map { attr($0 as! AXUIElement, kAXDescriptionAttribute) as? String ?? "?" } ?? "none")")
let scroll = first(w, 0) { (attr($0, kAXRoleAttribute) as? String) == "AXScrollArea" && first($0, 0) { (attr($0, kAXSubroleAttribute) as? String) == "AXCollectionList" } != nil }!
if let bar = attr(scroll, kAXVerticalScrollBarAttribute) { print("scrollbar value \(attr(bar as! AXUIElement, kAXValueAttribute) ?? "nil" as AnyObject)") } else { print("no vertical scroll bar") }
_ = AXUIElementPerformAction(s, "AXScrollToVisible" as CFString); usleep(800_000)
print("after scroll-to-visible, next: \(attr(s, "AXNextContentSibling") != nil)")
if attr(s, "AXNextContentSibling") == nil, let kids = attr(s, kAXChildrenAttribute) as? [AXUIElement], let lk = kids.last {
    _ = AXUIElementPerformAction(lk, "AXScrollToVisible" as CFString); usleep(800_000)
    print("after last child scroll, next: \(attr(s, "AXNextContentSibling") != nil)")
}
