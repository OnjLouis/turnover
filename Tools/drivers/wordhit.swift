// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import ApplicationServices
func attr(_ e: AXUIElement, _ a: String) -> AnyObject? { var v: AnyObject?; return AXUIElementCopyAttributeValue(e, a as CFString, &v) == .success ? v : nil }
func s(_ e: AXUIElement, _ a: String) -> String { (attr(e, a) as? String) ?? "" }
func kids(_ e: AXUIElement) -> [AXUIElement] { (attr(e, kAXChildrenAttribute) as? [AXUIElement]) ?? [] }
let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.microsoft.Word").first!
let ax = AXUIElementCreateApplication(app.processIdentifier)
let w = attr(ax, kAXFocusedWindowAttribute) as! AXUIElement
var layout: AXUIElement?
func find(_ e: AXUIElement) { if s(e, kAXRoleAttribute) == "AXLayoutArea" && s(e, kAXDescriptionAttribute) != "Document Thumbnails" && layout == nil { layout = e }; for c in kids(e) { find(c) } }
find(w)
var p = CGPoint.zero, z = CGSize.zero
AXValueGetValue(attr(layout!, kAXPositionAttribute) as! AXValue, .cgPoint, &p); AXValueGetValue(attr(layout!, kAXSizeAttribute) as! AXValue, .cgSize, &z)
var hit: AXUIElement?
let r = AXUIElementCopyElementAtPosition(ax, Float(p.x + z.width / 2), Float(p.y + 150), &hit)
print("layout at", p, z); print("hit:", r.rawValue, hit.map { s($0, kAXRoleAttribute) + " " + s($0, kAXDescriptionAttribute) } ?? "none")
usleep(500_000)
print("layout kids", kids(layout!).count)
