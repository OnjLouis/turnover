// SPDX-License-Identifier: GPL-3.0-or-later
// axpress <bundle-id> <identifier-or-description-or-title>: presses the first element whose identifier, description or title matches.
// Never an offer button: buy, get, rent, trial, subscribe, sign in, purchase (the rule; Excel's trial dialog, 10 Oct 2026).
import Foundation
import AppKit
import ApplicationServices
let a = CommandLine.arguments
guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: a[1]).first else { exit(1) }
let want = a[2]
func attr(_ e: AXUIElement, _ k: String) -> AnyObject? { var v: AnyObject?; return AXUIElementCopyAttributeValue(e, k as CFString, &v) == .success ? v : nil }
func find(_ e: AXUIElement, _ d: Int) -> AXUIElement? {
    if d > 40 { return nil }
    let id = attr(e, kAXIdentifierAttribute) as? String ?? "", desc = attr(e, kAXDescriptionAttribute) as? String ?? ""
    if id.contains("offerButton") { return nil }
    let title = attr(e, kAXTitleAttribute) as? String ?? ""
    let offer = ["buy", "get ", "rent", "trial", "free", "subscri", "sign in", "purchase"].contains { (desc + " " + title).lowercased().contains($0) }
    if offer { return nil }
    if id == want || desc == want || title == want || (want.hasSuffix("*") && desc.hasPrefix(String(want.dropLast()))) { return e }
    for k in (attr(e, kAXChildrenAttribute) as? [AXUIElement]) ?? [] { if let f = find(k, d + 1) { return f } }
    return nil
}
let ax = AXUIElementCreateApplication(app.processIdentifier)
guard let w = (attr(ax, kAXWindowsAttribute) as? [AXUIElement])?.first, let e = find(w, 0) else { print("not found"); exit(1) }
print("press: \(AXUIElementPerformAction(e, kAXPressAction as CFString).rawValue)")
