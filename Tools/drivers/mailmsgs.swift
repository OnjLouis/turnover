// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import ApplicationServices
func attr(_ e: AXUIElement, _ a: String) -> AnyObject? { var v: AnyObject?; return AXUIElementCopyAttributeValue(e, a as CFString, &v) == .success ? v : nil }
func s(_ e: AXUIElement, _ a: String) -> String { (attr(e, a) as? String) ?? "" }
func kids(_ e: AXUIElement) -> [AXUIElement] { (attr(e, kAXChildrenAttribute) as? [AXUIElement]) ?? [] }
let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.mail").first!
let ax = AXUIElementCreateApplication(app.processIdentifier)
let w = attr(ax, kAXMainWindowAttribute) as! AXUIElement
var q = [w]; var t: AXUIElement?
while !q.isEmpty && t == nil { let e = q.removeFirst(); if s(e, kAXRoleAttribute) == "AXTable" && s(e, kAXDescriptionAttribute) == "messages" { t = e }; q += kids(e) }
print("focus messages:", AXUIElementSetAttributeValue(t!, kAXFocusedAttribute as CFString, kCFBooleanTrue).rawValue)
