// SPDX-License-Identifier: GPL-3.0-or-later
// axattrs <bundle-id> <role> [depth]: attribute names of the first element with that role in the focused window,
// and the values of its AXSelected*, AXFocused*, AXRows/AXColumns counts.
import Foundation
import AppKit
import ApplicationServices
let args = CommandLine.arguments
guard args.count >= 3, let app = NSRunningApplication.runningApplications(withBundleIdentifier: args[1]).first else { print("usage"); exit(1) }
let ax = AXUIElementCreateApplication(app.processIdentifier)
func attr(_ e: AXUIElement, _ n: String) -> CFTypeRef? { var v: CFTypeRef?; return AXUIElementCopyAttributeValue(e, n as CFString, &v) == .success ? v : nil }
func role(_ e: AXUIElement) -> String { attr(e, "AXRole") as? String ?? "?" }
var win: CFTypeRef?; AXUIElementCopyAttributeValue(ax, "AXFocusedWindow" as CFString, &win)
guard let w = win else { print("no window"); exit(1) }
var queue = [w as! AXUIElement]; var found: AXUIElement?; var n = 0
while !queue.isEmpty, n < 6000 { let e = queue.removeFirst(); n += 1; if role(e) == args[2] { found = e; break }; queue += (attr(e, "AXChildren") as? [AXUIElement]) ?? [] }
guard let t = found else { print("no \(args[2])"); exit(1) }
var names: CFArray?; AXUIElementCopyAttributeNames(t, &names)
print("attributes:", (names as? [String] ?? []).joined(separator: " "))
for a in (names as? [String] ?? []) where a.hasPrefix("AXSelected") || a.hasPrefix("AXFocused") || a == "AXRowCount" || a == "AXColumnCount" {
    let v = attr(t, a)
    if let arr = v as? [AXUIElement] { print(a, "=", arr.count, "elements:", arr.prefix(3).map { role($0) + " " + ((attr($0, "AXValue") as? String) ?? (attr($0, "AXDescription") as? String) ?? "") }) }
    else { print(a, "=", v.map { String(describing: $0) } ?? "nil") }
}
var pnames: CFArray?; AXUIElementCopyParameterizedAttributeNames(t, &pnames)
print("parameterized:", (pnames as? [String] ?? []).joined(separator: " "))
