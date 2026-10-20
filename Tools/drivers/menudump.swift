// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import ApplicationServices
setvbuf(stdout, nil, _IONBF, 0)
func attr(_ e: AXUIElement, _ a: String) -> AnyObject? { var v: AnyObject?; return AXUIElementCopyAttributeValue(e, a as CFString, &v) == .success ? v : nil }
func s(_ e: AXUIElement, _ a: String) -> String { (attr(e, a) as? String) ?? "" }
func kids(_ e: AXUIElement) -> [AXUIElement] { (attr(e, kAXChildrenAttribute) as? [AXUIElement]) ?? [] }
let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.mail").first!
let ax = AXUIElementCreateApplication(app.processIdentifier)
// find open menus: AXMenu elements anywhere under the app's windows / app
var menus: [AXUIElement] = []
func find(_ e: AXUIElement, _ d: Int) { if s(e, kAXRoleAttribute) == "AXMenu" { menus.append(e) }; if d < 6 { for c in kids(e) { find(c, d + 1) } } }
for w in (attr(ax, kAXWindowsAttribute) as? [AXUIElement]) ?? [] { find(w, 0) }
find(ax, 0)
print("menus:", menus.count)
for m in menus {
  print("== menu with", kids(m).count)
  for (i, k) in kids(m).enumerated() {
    var names: CFArray?; AXUIElementCopyAttributeNames(k, &names)
    let extra = ((names as? [String]) ?? []).filter { !["AXRole","AXRoleDescription","AXParent","AXChildren","AXTitle","AXEnabled","AXPosition","AXSize","AXFrame","AXTopLevelUIElement","AXWindow","AXHelp","AXSelected","AXSubrole","AXDescription","AXChildrenInNavigationOrder"].contains($0) }
    let vals = extra.map { a -> String in let v = attr(k, a); return "\(a)=\(v.map { "\($0)" }?.prefix(20) ?? "nil")" }
    print(i, "[\(s(k, kAXTitleAttribute))]", "enabled=\(attr(k, kAXEnabledAttribute) ?? "nil" as AnyObject)", "kids=\(kids(k).count)", vals.joined(separator: " "))
    if i > 30 { break }
  }
}
