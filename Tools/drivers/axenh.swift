// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import ApplicationServices
func attr(_ e: AXUIElement, _ a: String) -> AnyObject? { var v: AnyObject?; return AXUIElementCopyAttributeValue(e, a as CFString, &v) == .success ? v : nil }
let app = NSRunningApplication.runningApplications(withBundleIdentifier: (CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "com.microsoft.Word")).first!
let ax = AXUIElementCreateApplication(app.processIdentifier)
print("enhanced:", attr(ax, "AXEnhancedUserInterface") ?? "nil", "manual:", attr(ax, "AXManualAccessibility") ?? "nil")
if CommandLine.arguments.count > 1 { print("set enhanced:", AXUIElementSetAttributeValue(ax, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue).rawValue) }
