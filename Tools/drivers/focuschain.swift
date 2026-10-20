// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import ApplicationServices
func attr(_ e: AXUIElement, _ a: String) -> AnyObject? { var v: AnyObject?; return AXUIElementCopyAttributeValue(e, a as CFString, &v) == .success ? v : nil }
func s(_ e: AXUIElement, _ a: String) -> String { (attr(e, a) as? String) ?? "" }
let bundle = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "com.apple.mail"
let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundle).first!
let ax = AXUIElementCreateApplication(app.processIdentifier)
var e = attr(ax, kAXFocusedUIElementAttribute) as! AXUIElement?
var d = 0
while let x = e, d < 12 { print(String(repeating: " ", count: d), s(x, kAXRoleAttribute), s(x, kAXSubroleAttribute), "title=\(s(x, kAXTitleAttribute))", "desc=\(s(x, kAXDescriptionAttribute))", "id=\(s(x, kAXIdentifierAttribute))"); e = attr(x, kAXParentAttribute) as! AXUIElement?; d += 1 }
