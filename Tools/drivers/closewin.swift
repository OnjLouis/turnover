// SPDX-License-Identifier: GPL-3.0-or-later
// closewin <bundle> <title prefix>: presses the close button of that app's windows whose title starts with the prefix.
import AppKit
import ApplicationServices
let args = CommandLine.arguments
let app = NSRunningApplication.runningApplications(withBundleIdentifier: args[1]).first!
let ax = AXUIElementCreateApplication(app.processIdentifier)
func a(_ e: AXUIElement, _ k: String) -> AnyObject? { var v: AnyObject?; return AXUIElementCopyAttributeValue(e, k as CFString, &v) == .success ? v : nil }
for w in (a(ax, "AXWindows") as? [AXUIElement]) ?? [] where ((a(w, "AXTitle") as? String) ?? "").hasPrefix(args[2]) {
    if let b = a(w, "AXCloseButton") { print("closed:", AXUIElementPerformAction(b as! AXUIElement, "AXPress" as CFString).rawValue) }
}
