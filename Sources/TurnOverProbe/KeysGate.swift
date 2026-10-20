// SPDX-License-Identifier: GPL-3.0-or-later
// keys: post key events to an app by pid without activating it (Muteny showed
// Steam accepts keys posted to its process while another app holds the
// keyboard). Used to open Word's dialogs for inspection: --bundle id --keys "cmd+f,escape".
// tree: print the focused window's element tree, shallow, for dialog mapping.
import Foundation
import AppKit
import ApplicationServices
import Carbon.HIToolbox
import TurnOverAX

private let keyCodes: [String: CGKeyCode] = [
    "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9, "b": 11, "q": 12, "w": 13, "e": 14, "r": 15,
    "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "9": 25, "7": 26, "8": 28, "0": 29, "o": 31, "u": 32,
    "i": 34, "p": 35, "l": 37, "j": 38, "k": 40, "n": 45, "m": 46, "return": 36, "tab": 48, "space": 49, "delete": 51, "escape": 53,
    "left": 123, "right": 124, "down": 125, "up": 126,
]

func runKeysGate(_ args: [String]) {
    let opts = Options(args)
    guard let app = resolveApp(opts) else { Log.line("no target app"); return }
    let pid = app.processIdentifier
    let src = CGEventSource(stateID: .hidSystemState)
    for combo in (opts.string("keys") ?? "").split(separator: ",").map({ $0.trimmingCharacters(in: .whitespaces).lowercased() }) {
        let parts = combo.split(separator: "+").map(String.init)
        guard let keyName = parts.last, let code = keyCodes[keyName] else { Log.line("unknown key \(combo)"); continue }
        var flags: CGEventFlags = []
        for m in parts.dropLast() {
            switch m { case "cmd", "command": flags.insert(.maskCommand); case "shift": flags.insert(.maskShift)
                       case "opt", "option", "alt": flags.insert(.maskAlternate); case "ctrl", "control": flags.insert(.maskControl); default: break }
        }
        for down in [true, false] {
            guard let e = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: down) else { continue }
            e.flags = flags
            e.postToPid(pid)
            usleep(30_000)
        }
        Log.line("posted \(combo) to \(app.localizedName ?? "?") pid \(pid)")
        usleep(UInt32(opts.double("gap", 0.8) * 1_000_000))
    }
}

func runTreeGate(_ args: [String]) {
    let opts = Options(args)
    guard let app = resolveApp(opts) else { Log.line("no target app"); return }
    let appEl = AXUIElementCreateApplication(app.processIdentifier)
    AXUIElementSetMessagingTimeout(appEl, 3)
    let maxDepth = opts.int("depth", 7)
    let maxCount = opts.int("max", 400)
    let onlyInteresting = !opts.has("all")
    guard let root = (opts.has("focused") ? appEl.element(kAXFocusedUIElementAttribute) : nil) ?? appEl.element(kAXFocusedWindowAttribute) else { Log.line("no window"); return }
    if let f = appEl.element(kAXFocusedUIElementAttribute) {
        Log.line("focused element: \(f.role) \"\(f.string(kAXTitleAttribute) ?? f.string(kAXDescriptionAttribute) ?? "")\"")
    }
    Log.line("window \"\(root.string(kAXTitleAttribute) ?? "")\" subrole \(root.string(kAXSubroleAttribute) ?? "-")")
    var count = 0
    func walk(_ e: AXUIElement, _ depth: Int) {
        guard depth <= maxDepth, count < maxCount else { return }
        let role = e.role
        let title = e.string(kAXTitleAttribute) ?? ""
        let desc = e.string(kAXDescriptionAttribute) ?? ""
        var value = ""
        if let v = e.attr(kAXValueAttribute) { if let s = v as? String { value = String(s.prefix(40)) } else if let n = v as? NSNumber { value = n.stringValue } }
        let interesting = !(role == "AXGroup" && title.isEmpty && desc.isEmpty) && role != "AXStaticText" || !value.isEmpty
        if !onlyInteresting || interesting || depth == 0 {
            count += 1
            let focused = (e.attr(kAXFocusedAttribute) as? Bool) == true ? " FOCUSED" : ""
            Log.line(String(repeating: "  ", count: depth) + "\(role) \"\(title)\" \(desc.isEmpty ? "" : "desc \"\(desc)\" ")\(value.isEmpty ? "" : "value \"\(value)\" ")\(e.string(kAXRoleDescriptionAttribute).map { "(\($0))" } ?? "")\(focused)")
        }
        for c in e.elements(kAXChildrenAttribute) { walk(c, depth + 1) }
    }
    walk(root, 0)
    Log.line("\(count) elements listed")
}
