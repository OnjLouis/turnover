// SPDX-License-Identifier: GPL-3.0-or-later
// axtree <bundle-id> [maxDepth] [maxNodes]: the focused window's accessibility tree, one element a line. Read-only.
import Foundation
import AppKit
import ApplicationServices
setvbuf(stdout, nil, _IONBF, 0)
let a = CommandLine.arguments
guard a.count > 1, let app = NSRunningApplication.runningApplications(withBundleIdentifier: a[1]).first else { print("not running"); exit(1) }
let maxDepth = a.count > 2 ? Int(a[2])! : 30
let maxNodes = a.count > 3 ? Int(a[3])! : 3000
let ax = AXUIElementCreateApplication(app.processIdentifier)
AXUIElementSetMessagingTimeout(ax, 3)
func attr(_ e: AXUIElement, _ k: String) -> AnyObject? { var v: AnyObject?; return AXUIElementCopyAttributeValue(e, k as CFString, &v) == .success ? v : nil }
func str(_ e: AXUIElement, _ k: String) -> String? { (attr(e, k) as? String).flatMap { $0.isEmpty ? nil : $0 } }
func kids(_ e: AXUIElement) -> [AXUIElement] { (attr(e, kAXChildrenAttribute) as? [AXUIElement]) ?? [] }
func actions(_ e: AXUIElement) -> [String] { var n: CFArray?; AXUIElementCopyActionNames(e, &n); return ((n as? [String]) ?? []).filter { !["AXScrollToVisible", "AXShowMenu"].contains($0) } }
var nodes = 0
func dump(_ e: AXUIElement, _ d: Int) {
    guard d <= maxDepth, nodes < maxNodes else { return }
    nodes += 1
    var parts = [str(e, kAXRoleAttribute) ?? "?"]
    if let s = str(e, kAXSubroleAttribute) { parts.append("/\(s)") }
    if let t = str(e, kAXTitleAttribute) { parts.append("title=\"\(t.prefix(80))\"") }
    if let t = str(e, kAXDescriptionAttribute) { parts.append("desc=\"\(t.prefix(80))\"") }
    if let v = attr(e, kAXValueAttribute) { let s = "\(v)"; if !s.isEmpty { parts.append("value=\"\(s.prefix(60))\"") } }
    if let t = str(e, kAXHelpAttribute) { parts.append("help=\"\(t.prefix(60))\"") }
    if let t = str(e, kAXIdentifierAttribute) { parts.append("id=\(t.prefix(60))") }
    if (attr(e, kAXFocusedAttribute) as? Bool) == true { parts.append("FOCUSED") }
    if (attr(e, kAXSelectedAttribute) as? Bool) == true { parts.append("SELECTED") }
    let acts = actions(e); if !acts.isEmpty { parts.append("[\(acts.joined(separator: ","))]") }
    print(String(repeating: "  ", count: d) + parts.joined(separator: " "))
    for k in kids(e) { dump(k, d + 1) }
}
let win = (attr(ax, kAXFocusedWindowAttribute) as! AXUIElement?) ?? ((attr(ax, kAXWindowsAttribute) as? [AXUIElement])?.first)
guard let w = win else { print("no window"); exit(1) }
dump(w, 0)
if let f = attr(ax, kAXFocusedUIElementAttribute) { print("FOCUS: \(str(f as! AXUIElement, kAXRoleAttribute) ?? "?") \(str(f as! AXUIElement, kAXDescriptionAttribute) ?? str(f as! AXUIElement, kAXTitleAttribute) ?? "")") }
print("\(nodes) nodes")
