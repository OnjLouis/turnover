// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import ApplicationServices
func attr(_ e: AXUIElement, _ a: String) -> AnyObject? { var v: AnyObject?; return AXUIElementCopyAttributeValue(e, a as CFString, &v) == .success ? v : nil }
let app = NSRunningApplication.runningApplications(withBundleIdentifier: CommandLine.arguments[1]).first!
let ax = AXUIElementCreateApplication(app.processIdentifier)
let f = attr(ax, kAXFocusedUIElementAttribute) as! AXUIElement
print(attr(f, kAXRoleAttribute) ?? "", attr(f, kAXIdentifierAttribute) ?? "", "value=[\(attr(f, kAXValueAttribute) ?? "" as AnyObject)]")
