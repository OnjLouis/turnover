// SPDX-License-Identifier: GPL-3.0-or-later
// spellprobe: the focused text field's misspelling marks, as the app reports them to accessibility. Read-only.
// Prints each run with AXMisspelled or AXMarkedMisspelled, masked to length and first letter; no keys sent.
import AppKit
import ApplicationServices
func attr(_ e: AXUIElement, _ k: String) -> AnyObject? { var v: AnyObject?; return AXUIElementCopyAttributeValue(e, k as CFString, &v) == .success ? v : nil }
// An app by bundle id (its own focused element, in the background too), else the system-wide focus.
let target: AXUIElement = {
    if CommandLine.arguments.count > 1, let app = NSRunningApplication.runningApplications(withBundleIdentifier: CommandLine.arguments[1]).first {
        return AXUIElementCreateApplication(app.processIdentifier)
    }
    return AXUIElementCreateSystemWide()
}()
func kids(_ e: AXUIElement) -> [AXUIElement] { (attr(e, kAXChildrenAttribute) as? [AXUIElement]) ?? [] }
// The focused element; else, in the focused or main window, the element marked focused, else the first text box with text.
var found: AXUIElement? = attr(target, kAXFocusedUIElementAttribute).map { $0 as! AXUIElement }
if found == nil, let w = (attr(target, kAXFocusedWindowAttribute) ?? attr(target, kAXMainWindowAttribute)) {
    var q = [w as! AXUIElement]; var n = 0; var firstText: AXUIElement?
    while !q.isEmpty && n < 4000 {
        let e = q.removeFirst(); n += 1
        let role = (attr(e, kAXRoleAttribute) as? String) ?? ""
        if ["AXTextArea", "AXTextField"].contains(role) {
            if (attr(e, kAXFocusedAttribute) as? Bool) == true { found = e; break }
            if firstText == nil, let v = attr(e, kAXValueAttribute) as? String, !v.isEmpty { firstText = e }
        }
        q += kids(e)
    }
    if found == nil { found = firstText; if found != nil { print("(no focused element; the first text box with text)") } }
}
guard let el = found else { print("no focused element and no text box found"); exit(1) }
let role = (attr(el, kAXRoleAttribute) as? String) ?? "?"
let n = (attr(el, kAXNumberOfCharactersAttribute) as? Int) ?? ((attr(el, kAXValueAttribute) as? String)?.count ?? 0)
print("focus: \(role), \(n) characters")
var range = CFRange(location: 0, length: n)
guard let rv = AXValueCreate(.cfRange, &range) else { exit(1) }
var out: AnyObject?
let r = AXUIElementCopyParameterizedAttributeValue(el, kAXAttributedStringForRangeParameterizedAttribute as CFString, rv, &out)
guard r == .success, let a = out as? NSAttributedString else { print("no attributed string: \(r.rawValue)"); exit(1) }
let ns = a.string as NSString
for key in ["AXMisspelled", "AXMarkedMisspelled"] {
    var runs: [String] = []
    a.enumerateAttribute(NSAttributedString.Key(key), in: NSRange(location: 0, length: a.length)) { v, rg, _ in
        if (v as? NSNumber)?.boolValue == true { let w = ns.substring(with: rg); runs.append("\(rg.location)+\(rg.length) '\(w.prefix(1))…'") }
    }
    print("\(key): \(runs.isEmpty ? "none" : runs.joined(separator: ", "))")
}
var names: CFArray?; AXUIElementCopyParameterizedAttributeNames(el, &names)
print("parameterized attributes: \(((names as? [String]) ?? []).filter { $0.contains("Misspell") || $0.contains("Spell") })")
