// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import ApplicationServices
func attr(_ e: AXUIElement, _ a: String) -> AnyObject? { var v: AnyObject?; return AXUIElementCopyAttributeValue(e, a as CFString, &v) == .success ? v : nil }
func s(_ e: AXUIElement, _ a: String) -> String { (attr(e, a) as? String) ?? "" }
func kids(_ e: AXUIElement) -> [AXUIElement] { (attr(e, kAXChildrenAttribute) as? [AXUIElement]) ?? [] }
let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.microsoft.Word").first!
let ax = AXUIElementCreateApplication(app.processIdentifier)
let f = attr(ax, kAXFocusedUIElementAttribute) as! AXUIElement?
print("focused:", f.map { s($0, kAXRoleAttribute) + " " + s($0, kAXDescriptionAttribute) } ?? "none")
for w in (attr(ax, kAXWindowsAttribute) as? [AXUIElement]) ?? [] {
    print("window:", s(w, kAXTitleAttribute))
    func walk(_ e: AXUIElement, _ d: Int) {
        let r = s(e, kAXRoleAttribute)
        if r == "AXTabGroup" || r == "AXToolbar" { return }
        if ["AXLayoutArea", "AXTextArea", "AXScrollArea", "AXGroup"].contains(r) && d < 9 { print(String(repeating: " ", count: d), r, s(e, kAXDescriptionAttribute), "kids", kids(e).count) }
        if d < 9 { for c in kids(e) { walk(c, d + 1) } }
    }
    walk(w, 0)
}
