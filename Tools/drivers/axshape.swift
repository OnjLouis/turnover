// SPDX-License-Identifier: GPL-3.0-or-later
// axshape <bundle-id> [maxdepth] [maxnodes]: an app's front window as a tree of roles, identifiers and actions, with
// every piece of text masked (first letter and length), so private content (messages) is never printed.
import AppKit
import ApplicationServices
let a = CommandLine.arguments
guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: a[1]).first else { print("not running"); exit(1) }
let maxDepth = a.count > 2 ? Int(a[2])! : 25, maxNodes = a.count > 3 ? Int(a[3])! : 400
let ax = AXUIElementCreateApplication(app.processIdentifier); AXUIElementSetMessagingTimeout(ax, 1)
func attr(_ e: AXUIElement, _ k: String) -> AnyObject? { var v: AnyObject?; return AXUIElementCopyAttributeValue(e, k as CFString, &v) == .success ? v : nil }
func s(_ e: AXUIElement, _ k: String) -> String { (attr(e, k) as? String) ?? "" }
func mask(_ t: String) -> String { t.isEmpty ? "" : "\"\(t.prefix(1))…(\(t.count))\"" }
func acts(_ e: AXUIElement) -> String { var c: CFArray?; AXUIElementCopyActionNames(e, &c); return ((c as? [String]) ?? []).filter { !$0.hasPrefix("AXScroll") && $0 != "AXCancel" && $0 != "AXShowMenu" }.map { $0.hasPrefix("Name:") ? "custom:" + ($0.dropFirst(5).components(separatedBy: CharacterSet(charactersIn: " ,\n")).first ?? "") : $0 }.joined(separator: ",") }
var n = 0
func walk(_ e: AXUIElement, _ d: Int) {
    n += 1; guard n <= maxNodes, d <= maxDepth else { return }
    let r = s(e, kAXRoleAttribute), sub = s(e, kAXSubroleAttribute), id = s(e, kAXIdentifierAttribute)
    let desc = s(e, kAXDescriptionAttribute), title = s(e, kAXTitleAttribute)
    let val = (attr(e, kAXValueAttribute) as? String) ?? ""
    let kids = (attr(e, kAXChildrenAttribute) as? [AXUIElement]) ?? []
    var line = String(repeating: " ", count: d) + r + (sub.isEmpty ? "" : "/" + sub)
    if !id.isEmpty { line += " id=" + id.prefix(60) }
    if !desc.isEmpty { line += " desc=" + mask(desc) }
    if !title.isEmpty { line += " title=" + mask(title) }
    if !val.isEmpty { line += " val=" + mask(val) }
    let ac = acts(e); if !ac.isEmpty { line += " [" + ac + "]" }
    if (attr(e, kAXFocusedAttribute) as? Bool) == true { line += " FOCUSED" }
    if kids.count > 12 { line += " (\(kids.count) children)" }
    print(line)
    for k in kids.prefix(12) { walk(k, d + 1) }
}
guard let w = attr(ax, kAXFocusedWindowAttribute) as! AXUIElement? ?? (attr(ax, kAXWindowsAttribute) as? [AXUIElement])?.first else { print("no window"); exit(0) }
print("window title=" + mask(s(w, kAXTitleAttribute)))
walk(w, 0)
