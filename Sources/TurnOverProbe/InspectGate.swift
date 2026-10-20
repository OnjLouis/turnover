// SPDX-License-Identifier: GPL-3.0-or-later
// inspect: what an app's focused window and focused element expose. Read-only.
//
// Prints the focused element's role, every attribute name and parameterized
// attribute name it advertises, the text-related values a reader needs
// (character count, selection, visible range, insertion line), and a census of
// roles in the focused window. Used first on Microsoft Word, 30 Sep 2026.
import Foundation
import ApplicationServices
import TurnOverAX
import AppKit

func runInspectGate(_ args: [String]) {
    let opts = Options(args)
    guard let app = resolveApp(opts) else { Log.line("no target app"); return }
    Log.line("target: \(app.localizedName ?? "?") (\(app.bundleIdentifier ?? "?"), pid \(app.processIdentifier))")
    let appEl = AXUIElementCreateApplication(app.processIdentifier)
    AXUIElementSetMessagingTimeout(appEl, 5)

    let enhanced = appEl.attr("AXEnhancedUserInterface")
    Log.line("AXEnhancedUserInterface on the app: \(enhanced.map { "\($0)" } ?? "absent")")

    guard let win = appEl.element(kAXFocusedWindowAttribute) ?? appEl.elements(kAXWindowsAttribute).first else {
        Log.line("no window"); return
    }
    Log.line("focused window: \"\(win.string(kAXTitleAttribute) ?? "?")\" role \(win.role) subrole \(win.string(kAXSubroleAttribute) ?? "-")")

    // Census of the window, bounded.
    var counts: [String: Int] = [:]
    var queue: [AXUIElement] = [win]
    var visited = 0
    var textLike: [AXUIElement] = []
    let census = timed {
        while !queue.isEmpty && visited < 4000 {
            let e = queue.removeFirst()
            visited += 1
            let r = e.role
            counts[r, default: 0] += 1
            if r == "AXTextArea" || r == "AXTextField" || r == "AXWebArea" || r == "AXLayoutArea" { textLike.append(e) }
            queue.append(contentsOf: e.elements(kAXChildrenAttribute))
        }
    }
    Log.line(String(format: "census: %d elements in %.0f ms%@", visited, census.ms, queue.isEmpty ? "" : " (stopped at the cap)"))
    for (role, n) in counts.sorted(by: { $0.value > $1.value }) { Log.line("  \(n)\t\(role)") }

    // The focused element, and any text-like elements found.
    var targets: [(String, AXUIElement)] = []
    if let f = appEl.element(kAXFocusedUIElementAttribute) { targets.append(("focused element", f)) }
    for (i, t) in textLike.prefix(3).enumerated() { targets.append(("text-like #\(i + 1)", t)) }

    for (label, el) in targets {
        Log.line("--- \(label): role \(el.role) subrole \(el.string(kAXSubroleAttribute) ?? "-") desc \"\(el.string(kAXDescriptionAttribute) ?? "")\" title \"\(el.string(kAXTitleAttribute) ?? "")\" roleDescription \"\(el.string(kAXRoleDescriptionAttribute) ?? "")\"")
        var names: CFArray?
        if AXUIElementCopyAttributeNames(el, &names) == .success, let list = names as? [String] {
            Log.line("attributes (\(list.count)): \(list.joined(separator: ", "))")
        }
        var pnames: CFArray?
        if AXUIElementCopyParameterizedAttributeNames(el, &pnames) == .success, let list = pnames as? [String] {
            Log.line("parameterized (\(list.count)): \(list.joined(separator: ", "))")
        }
        for name in ["AXNumberOfCharacters", "AXSelectedTextRange", "AXVisibleCharacterRange", "AXInsertionPointLineNumber", "AXSelectedText", "AXPlaceholderValue"] {
            let r = timed { el.attrError(name) }
            let v: String
            if let range = cfRange(r.value.0) { v = "\(range.location)+\(range.length)" }
            else if let s = r.value.0 as? String { v = "\"\(s.prefix(60))\"" }
            else if let n = r.value.0 as? NSNumber { v = "\(n)" }
            else { v = describeError(r.value.1) }
            Log.line(String(format: "  %@ = %@ (%.2f ms)", name, v, r.ms))
        }
        // Parameterized reads around the current selection, if any.
        if let sel = cfRange(el.attr(kAXSelectedTextRangeAttribute)) {
            let lfi = timed { el.paramError("AXLineForIndex", sel.location as CFNumber) }
            let lineNo = (lfi.value.0 as? NSNumber)?.intValue
            Log.line(String(format: "  AXLineForIndex(%d) = %@ (%.2f ms)", sel.location, lineNo.map { "\($0)" } ?? describeError(lfi.value.1), lfi.ms))
            if let lineNo {
                let rfl = timed { el.paramError("AXRangeForLine", lineNo as CFNumber) }
                if let lr = cfRange(rfl.value.0) {
                    Log.line(String(format: "  AXRangeForLine(%d) = %d+%d (%.2f ms)", lineNo, lr.location, lr.length, rfl.ms))
                    let sfr = timed { el.paramError("AXStringForRange", axRangeValue(lr.location, lr.length)) }
                    Log.line(String(format: "  AXStringForRange(line) = \"%@\" (%.2f ms)", ((sfr.value.0 as? String) ?? describeError(sfr.value.1)).prefix(80) as CVarArg, sfr.ms))
                    let asr = timed { el.paramError("AXAttributedStringForRange", axRangeValue(lr.location, lr.length)) }
                    let attrs = (asr.value.0 as? NSAttributedString).map { a -> String in
                        var keys = Set<String>()
                        a.enumerateAttributes(in: NSRange(location: 0, length: a.length)) { d, _, _ in for k in d.keys { keys.insert(k.rawValue) } }
                        return keys.sorted().joined(separator: ", ")
                    }
                    Log.line(String(format: "  AXAttributedStringForRange(line): %@ (%.2f ms)", attrs ?? describeError(asr.value.1), asr.ms))
                } else {
                    Log.line("  AXRangeForLine(\(lineNo)): \(describeError(rfl.value.1))")
                }
            }
            let sfr2 = timed { el.paramError("AXStringForRange", axRangeValue(max(0, sel.location - 200), 400)) }
            Log.line(String(format: "  AXStringForRange(400 chars around caret): %d chars (%.2f ms, %@)", ((sfr2.value.0 as? String)?.count ?? -1), sfr2.ms, describeError(sfr2.value.1)))
            let bounds = timed { el.paramError("AXBoundsForRange", axRangeValue(sel.location, 1)) }
            Log.line(String(format: "  AXBoundsForRange(caret): %@ (%.2f ms)", describeError(bounds.value.1), bounds.ms))
        }
        if opts.has("value") {
            let value = timed { el.attrError(kAXValueAttribute) }
            Log.line(String(format: "  AXValue: %d UTF-16 units in %.1f ms (%@)", (value.value.0 as? String)?.utf16.count ?? -1, value.ms, describeError(value.value.1)))
        }
    }
}
