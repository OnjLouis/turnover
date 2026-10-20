// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
import AppKit
import ApplicationServices
let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.AppStore").first!
func attr(_ e: AXUIElement, _ k: String) -> AnyObject? { var v: AnyObject?; return AXUIElementCopyAttributeValue(e, k as CFString, &v) == .success ? v : nil }
func first(_ e: AXUIElement, _ d: Int, _ t: (AXUIElement) -> Bool) -> AXUIElement? {
    if t(e) { return e }; if d > 30 { return nil }
    for k in (attr(e, kAXChildrenAttribute) as? [AXUIElement]) ?? [] { if let f = first(k, d + 1, t) { return f } }
    return nil
}
let w = (attr(AXUIElementCreateApplication(app.processIdentifier), kAXWindowsAttribute) as! [AXUIElement])[0]
var s = first(w, 0) { (attr($0, kAXSubroleAttribute) as? String) == "AXSectionList" }!
print("visible: \(attr(s, kAXDescriptionAttribute) as? String ?? "") index \(attr(s, "AXIndex") ?? "nil" as AnyObject)")
if let f = attr(s, "AXFirstContentSibling") { print("first sibling: \(attr(f as! AXUIElement, kAXDescriptionAttribute) as? String ?? "") index \(attr(f as! AXUIElement, "AXIndex") ?? "nil" as AnyObject)") }
var n = 0
while let p = attr(s, "AXPreviousContentSibling"), n < 40 { s = p as! AXUIElement; n += 1; print("  prev \(n): \(attr(s, kAXDescriptionAttribute) as? String ?? "") index \(attr(s, "AXIndex") ?? "nil" as AnyObject)") }
