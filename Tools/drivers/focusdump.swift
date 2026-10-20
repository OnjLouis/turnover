// SPDX-License-Identifier: GPL-3.0-or-later
// focusdump <bundle>: every attribute of the focused element and its parent, values shortened. For test documents only.
import AppKit
import ApplicationServices
let app = NSRunningApplication.runningApplications(withBundleIdentifier: CommandLine.arguments[1]).first!
let ax = AXUIElementCreateApplication(app.processIdentifier)
func a(_ e: AXUIElement, _ k: String) -> AnyObject? { var v: AnyObject?; return AXUIElementCopyAttributeValue(e, k as CFString, &v) == .success ? v : nil }
func dump(_ e: AXUIElement, _ label: String) {
    var n: CFArray?; AXUIElementCopyAttributeNames(e, &n)
    print("== \(label)")
    for k in (n as? [String]) ?? [] {
        let v = a(e, k); var s = v.map { "\($0)" } ?? "nil"
        if let arr = v as? [AnyObject] { s = "[\(arr.count) items]" }
        if let v, CFGetTypeID(v) == AXUIElementGetTypeID() { s = "element \(a(v as! AXUIElement, "AXRole") ?? "" as AnyObject)" }
        print("  \(k) = \(s.replacingOccurrences(of: "\n", with: " ").prefix(110))")
    }
    var acts: CFArray?; AXUIElementCopyActionNames(e, &acts); print("  actions: \((acts as? [String]) ?? [])")
}
guard let f = a(ax, "AXFocusedUIElement") else { print("no focus"); exit(1) }
dump(f as! AXUIElement, "focus")
if let p = a(f as! AXUIElement, "AXParent") { dump(p as! AXUIElement, "parent") }
// focusdump <bundle> sel: the focused grid's AXSelectedCells, each with its children (Excel, Day 2).
if CommandLine.arguments.count > 2, CommandLine.arguments[2] == "sel" {
    var e: AXUIElement? = f as! AXUIElement
    while let x = e, (a(x, "AXRole") as? String) != "AXTable" { e = a(x, "AXParent").map { $0 as! AXUIElement } }
    guard let table = e else { print("no table"); exit(0) }
    let cells = (a(table, "AXSelectedCells") as? [AXUIElement]) ?? []
    print("selected cells: \(cells.count)")
    for c in cells.prefix(2) {
        dump(c, "selected cell")
        for k in ((a(c, "AXChildren") as? [AXUIElement]) ?? []).prefix(3) { dump(k, "  child") }
    }
}
