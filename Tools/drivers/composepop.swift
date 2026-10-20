// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import ApplicationServices
func attr(_ e: AXUIElement, _ a: String) -> AnyObject? { var v: AnyObject?; return AXUIElementCopyAttributeValue(e, a as CFString, &v) == .success ? v : nil }
func s(_ e: AXUIElement, _ a: String) -> String { (attr(e, a) as? String) ?? "" }
func kids(_ e: AXUIElement) -> [AXUIElement] { (attr(e, kAXChildrenAttribute) as? [AXUIElement]) ?? [] }
let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.mail").first!
let ax = AXUIElementCreateApplication(app.processIdentifier)
for w in (attr(ax, kAXWindowsAttribute) as? [AXUIElement]) ?? [] where s(w, kAXTitleAttribute) == "New Message" {
  func walk(_ e: AXUIElement, _ d: Int) {
    let r = s(e, kAXRoleAttribute)
    if ["AXPopUpButton", "AXTextField", "AXStaticText", "AXWebArea"].contains(r) {
      var settable: DarwinBoolean = false; AXUIElementIsAttributeSettable(e, kAXFocusedAttribute as CFString, &settable)
      print(String(repeating: " ", count: d), r, "title=\(s(e, kAXTitleAttribute))", "desc=\(s(e, kAXDescriptionAttribute))", "val=\(String(describing: attr(e, kAXValueAttribute) ?? "nil" as AnyObject).prefix(50))", "focusable=\(settable.boolValue)", "id=\(s(e, kAXIdentifierAttribute))")
    }
    if r == "AXWebArea" || r == "AXToolbar" { return }
    for c in kids(e) { walk(c, d + 1) }
  }
  walk(w, 0)
}
