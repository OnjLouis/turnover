// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
import AppKit
import ApplicationServices
let a = CommandLine.arguments
guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: a[1]).first else { exit(1) }
func attr(_ e: AXUIElement, _ k: String) -> AnyObject? { var v: AnyObject?; return AXUIElementCopyAttributeValue(e, k as CFString, &v) == .success ? v : nil }
func find(_ e: AXUIElement, _ d: Int) -> AXUIElement? {
    if (attr(e, kAXRoleAttribute) as? String) == "AXScrollArea" { return e }
    if d > 10 { return nil }
    for k in (attr(e, kAXChildrenAttribute) as? [AXUIElement]) ?? [] { if let f = find(k, d + 1) { return f } }
    return nil
}
let ax = AXUIElementCreateApplication(app.processIdentifier)
guard let w = (attr(ax, kAXWindowsAttribute) as? [AXUIElement])?.first, let s = find(w, 0) else { exit(1) }
for _ in 0..<(Int(a[2]) ?? 1) { print(AXUIElementPerformAction(s, (a.count > 3 ? a[3] : "AXScrollDownByPage") as CFString).rawValue) }
