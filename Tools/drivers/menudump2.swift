// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import ApplicationServices
setvbuf(stdout, nil, _IONBF, 0)
func attr(_ e: AXUIElement, _ a: String) -> AnyObject? { var v: AnyObject?; return AXUIElementCopyAttributeValue(e, a as CFString, &v) == .success ? v : nil }
func s(_ e: AXUIElement, _ a: String) -> String { (attr(e, a) as? String) ?? "" }
func kids(_ e: AXUIElement) -> [AXUIElement] { (attr(e, kAXChildrenAttribute) as? [AXUIElement]) ?? [] }
let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.mail").first!
let ax = AXUIElementCreateApplication(app.processIdentifier)
var target: AXUIElement?
func find(_ e: AXUIElement, _ d: Int) { if target != nil { return }; if s(e, kAXRoleAttribute) == "AXMenuItem" && s(e, kAXTitleAttribute) == "Move to" { target = e; return }; if d < 7 { for c in kids(e) { find(c, d + 1) } } }
for w in (attr(ax, kAXWindowsAttribute) as? [AXUIElement]) ?? [] { find(w, 0) }
guard let mv = target, let sub = kids(mv).first else { print("no Move to"); exit(0) }
for (i, k) in kids(sub).prefix(22).enumerated() {
  let en = attr(k, kAXEnabledAttribute)
  print(i, "[\(s(k, kAXTitleAttribute))]", "enabled=\(en.map { "\($0)" } ?? "nil") asBool=\((en as? Bool).map { "\($0)" } ?? "nil")", "id=\(s(k, kAXIdentifierAttribute))", "kids=\(kids(k).count)", "cmd=\(s(k, "AXMenuItemCmdChar"))")
}
