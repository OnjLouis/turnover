// SPDX-License-Identifier: GPL-3.0-or-later
// axclickitem <bundle-id> <desc-prefix>: clicks an item's left edge (its icon), never its offer (buy/get) button.
import Foundation
import AppKit
import ApplicationServices
setvbuf(stdout, nil, _IONBF, 0)
let a = CommandLine.arguments
guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: a[1]).first else { exit(1) }
func attr(_ e: AXUIElement, _ k: String) -> AnyObject? { var v: AnyObject?; return AXUIElementCopyAttributeValue(e, k as CFString, &v) == .success ? v : nil }
func frame(_ e: AXUIElement) -> CGRect? {
    guard let p = attr(e, kAXPositionAttribute), let s = attr(e, kAXSizeAttribute) else { return nil }
    var pt = CGPoint.zero, sz = CGSize.zero
    AXValueGetValue(p as! AXValue, .cgPoint, &pt); AXValueGetValue(s as! AXValue, .cgSize, &sz)
    return CGRect(origin: pt, size: sz)
}
func find(_ e: AXUIElement, _ d: Int) -> AXUIElement? {
    if d > 40 { return nil }
    let id = attr(e, kAXIdentifierAttribute) as? String ?? "", desc = attr(e, kAXDescriptionAttribute) as? String ?? ""
    if !id.contains("offerButton"), id.contains("shelfItem"), desc.hasPrefix(a[2]) { return e }
    for k in (attr(e, kAXChildrenAttribute) as? [AXUIElement]) ?? [] { if let f = find(k, d + 1) { return f } }
    return nil
}
func offer(_ e: AXUIElement, _ d: Int) -> AXUIElement? {
    if d > 6 { return nil }
    if ((attr(e, kAXIdentifierAttribute) as? String) ?? "").contains("offerButton") { return e }
    for k in (attr(e, kAXChildrenAttribute) as? [AXUIElement]) ?? [] { if let f = offer(k, d + 1) { return f } }
    return nil
}
let ax = AXUIElementCreateApplication(app.processIdentifier)
guard let w = (attr(ax, kAXWindowsAttribute) as? [AXUIElement])?.first, let item = find(w, 0) else { print("not found"); exit(1) }
if let sec = attr(item, kAXParentAttribute) { _ = AXUIElementPerformAction(sec as! AXUIElement, "AXScrollToVisible" as CFString); usleep(600_000) }
_ = AXUIElementPerformAction(item, "AXScrollToVisible" as CFString); usleep(600_000)
guard let f = frame(item) else { print("no frame"); exit(1) }
let o = offer(item, 0).flatMap(frame)
print("item \(f) offer \(o.map { "\($0)" } ?? "none")")
var pt = CGPoint(x: f.minX + min(20, f.width * 0.1), y: f.midY)
if let o, o.contains(pt) { print("point inside the offer button; not clicking"); exit(1) }
if let o, o.minX < f.minX + 40 { print("offer button at the left; not clicking"); exit(1) }
guard let wf = frame(w), wf.insetBy(dx: 10, dy: 60).contains(pt) else { print("point \(pt) is outside the window; not clicking"); exit(1) }
print("click at \(pt)")
for t in [CGEventType.leftMouseDown, .leftMouseUp] { CGEvent(mouseEventSource: nil, mouseType: t, mouseCursorPosition: pt, mouseButton: .left)?.post(tap: .cghidEventTap); usleep(30_000) }
