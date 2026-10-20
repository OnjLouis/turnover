// SPDX-License-Identifier: GPL-3.0-or-later
// axprobe <bundle-id> <id-substring>: actions and settable attributes of matching elements; "scroll" tries scrolling them.
import Foundation
import AppKit
import ApplicationServices
let a = CommandLine.arguments
guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: a[1]).first else { exit(1) }
func attr(_ e: AXUIElement, _ k: String) -> AnyObject? { var v: AnyObject?; return AXUIElementCopyAttributeValue(e, k as CFString, &v) == .success ? v : nil }
var found: [AXUIElement] = []
func walk(_ e: AXUIElement, _ d: Int) {
    if d > 40 { return }
    let id = attr(e, kAXIdentifierAttribute) as? String ?? "", role = attr(e, kAXRoleAttribute) as? String ?? "", sub = attr(e, kAXSubroleAttribute) as? String ?? ""
    if id.contains(a[2]) || role == a[2] || sub == a[2] { found.append(e) }
    for k in (attr(e, kAXChildrenAttribute) as? [AXUIElement]) ?? [] { walk(k, d + 1) }
}
let ax = AXUIElementCreateApplication(app.processIdentifier)
for w in (attr(ax, kAXWindowsAttribute) as? [AXUIElement]) ?? [] { walk(w, 0) }
for e in found {
    var n: CFArray?; AXUIElementCopyActionNames(e, &n)
    var names: CFArray?; AXUIElementCopyAttributeNames(e, &names)
    let settable = ((names as? [String]) ?? []).filter { var s: DarwinBoolean = false; AXUIElementIsAttributeSettable(e, $0 as CFString, &s); return s.boolValue }
    print("\(attr(e, kAXRoleAttribute) as? String ?? "") \(attr(e, kAXSubroleAttribute) as? String ?? "") actions=\((n as? [String]) ?? []) settable=\(settable) attrs=\(((names as? [String]) ?? []).joined(separator: ","))")
    if a.count > 3 {
        for act in ["AXScrollDownByPage"] { print("  \(act): \(AXUIElementPerformAction(e, act as CFString).rawValue)") }
    }
}
