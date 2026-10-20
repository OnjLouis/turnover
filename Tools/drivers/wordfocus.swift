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
var layout: AXUIElement?, scroll: AXUIElement?
func find(_ e: AXUIElement) { let r = s(e, kAXRoleAttribute); if r == "AXTabGroup" || r == "AXToolbar" { return }; if r == "AXLayoutArea" { layout = e; return }; if r == "AXScrollArea" { scroll = e }; for c in kids(e) { if layout == nil { find(c) } } }
find(w)
guard let l = layout else { print("no layout"); exit(0) }
func state(_ tag: String) { usleep(400_000); let f = attr(ax, kAXFocusedUIElementAttribute) as! AXUIElement?; print(tag, "→ focused", f.map { s($0, kAXRoleAttribute) + " " + s($0, kAXDescriptionAttribute) } ?? "none", "| layout kids", kids(l).count) }
state("start")
switch CommandLine.arguments.dropFirst().first ?? "" {
case "scroll": print(AXUIElementSetAttributeValue(scroll!, kAXFocusedAttribute as CFString, kCFBooleanTrue).rawValue); state("focus scroll area")
case "appfocus": print(AXUIElementSetAttributeValue(ax, kAXFocusedUIElementAttribute as CFString, l).rawValue); state("app focused element = layout")
case "press": print(AXUIElementPerformAction(l, kAXPressAction as CFString).rawValue); state("press layout")
case "visible": _ = attr(l, "AXVisibleChildren"); _ = attr(l, "AXChildrenInNavigationOrder"); _ = attr(scroll!, "AXVisibleChildren"); state("read visible")
default: print(AXUIElementSetAttributeValue(l, kAXFocusedAttribute as CFString, kCFBooleanTrue).rawValue); state("focus layout")
}
