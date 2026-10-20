// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import ApplicationServices
func attr(_ e: AXUIElement, _ a: String) -> AnyObject? { var v: AnyObject?; return AXUIElementCopyAttributeValue(e, a as CFString, &v) == .success ? v : nil }
func frame(_ e: AXUIElement) -> CGRect {
    var p = CGPoint.zero, s = CGSize.zero
    if let v = attr(e, kAXPositionAttribute) { AXValueGetValue(v as! AXValue, .cgPoint, &p) }
    if let v = attr(e, kAXSizeAttribute) { AXValueGetValue(v as! AXValue, .cgSize, &s) }
    return CGRect(origin: p, size: s)
}
let app = NSRunningApplication.runningApplications(withBundleIdentifier: CommandLine.arguments[1]).first!
let ax = AXUIElementCreateApplication(app.processIdentifier)
let w = attr(ax, kAXFocusedWindowAttribute) as! AXUIElement
print("window", frame(w))
func walk(_ e: AXUIElement, _ d: Int) {
    guard d < Int(CommandLine.arguments[2])! else { return }
    for c in (attr(e, kAXChildrenAttribute) as? [AXUIElement]) ?? [] {
        let r = attr(c, kAXRoleAttribute) as? String ?? ""
        let named = !((attr(c, kAXDescriptionAttribute) as? String ?? "") + (attr(c, kAXTitleAttribute) as? String ?? "")).isEmpty
        print(String(repeating: " ", count: d), r, attr(c, kAXSubroleAttribute) as? String ?? "", named ? "named" : "", frame(c))
        walk(c, d + 1)
    }
}
walk(w, 0)
