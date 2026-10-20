// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import ApplicationServices
setvbuf(stdout, nil, _IONBF, 0)
func attr(_ e: AXUIElement, _ a: String) -> AnyObject? { var v: AnyObject?; return AXUIElementCopyAttributeValue(e, a as CFString, &v) == .success ? v : nil }
func s(_ e: AXUIElement, _ a: String) -> String { (attr(e, a) as? String) ?? "" }
func kids(_ e: AXUIElement) -> [AXUIElement] { (attr(e, kAXChildrenAttribute) as? [AXUIElement]) ?? [] }
let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.microsoft.Word").first!
let ax = AXUIElementCreateApplication(app.processIdentifier)
let w = attr(ax, kAXFocusedWindowAttribute) as! AXUIElement
var layout: AXUIElement?, status: AXUIElement?
func find(_ e: AXUIElement) { let r = s(e, kAXRoleAttribute); if r == "AXLayoutArea" && s(e, kAXDescriptionAttribute) != "Document Thumbnails" && layout == nil { layout = e }; if s(e, kAXDescriptionAttribute) == "Status Bar" { status = e }; for c in kids(e) { find(c) } }
find(w)
let mode = CommandLine.arguments[1]
let attrs = mode.split(separator: ",").map(String.init)
func walk(_ e: AXUIElement) { for a in attrs { if a == "settable" { var b: DarwinBoolean = false; AXUIElementIsAttributeSettable(e, kAXFocusedAttribute as CFString, &b) } else { _ = attr(e, a) } }; for c in kids(e) { walk(c) } }
let target = CommandLine.arguments.count > 2 && CommandLine.arguments[2] == "window" ? w : status!
walk(target)
usleep(500_000)
print(mode, "on", CommandLine.arguments.count > 2 ? "window" : "status bar", "→ layout kids", kids(layout!).count)
