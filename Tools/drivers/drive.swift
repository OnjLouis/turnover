// SPDX-License-Identifier: GPL-3.0-or-later
// Real-looking key presses (unmarked, HID level), so TurnOver handles them as the owner's keys.
// Args: key names, "mod+key", "wait <seconds>", "type:<text>".
import AppKit
import CoreGraphics
var codes: [String: CGKeyCode] = ["left": 123, "right": 124, "down": 125, "up": 126, "escape": 53, "return": 36, "space": 49, "tab": 48, "f6": 97, "f5": 96, "f1": 122, "f2": 120, "f3": 99, "f4": 118, "f7": 98, "f8": 100, "f9": 101, "f10": 109,
                                  "'": 39, "home": 115, "end": 119, "pageup": 116, "pagedown": 121, "[": 33, "]": 30, "\\": 42, "f11": 103, "f12": 111, "backspace": 51, "-": 27, ".": 47, "/": 44, ";": 41, ",": 43, "`": 50]
for (k, v) in ["a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9, "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17,
               "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "9": 25, "7": 26, "8": 28, "0": 29, "o": 31, "u": 32, "i": 34, "p": 35, "l": 37, "j": 38, "k": 40, "n": 45, "m": 46] as [String: CGKeyCode] { codes[k] = v }
// The keypad (12 Oct 2026): kp0 to kp9, kpclear, kpenter, kpplus, kpminus, kpmultiply, kpdivide, kpequals, kpdecimal.
for (k, v) in ["kp0": 82, "kp1": 83, "kp2": 84, "kp3": 85, "kp4": 86, "kp5": 87, "kp6": 88, "kp7": 89, "kp8": 91, "kp9": 92,
               "kpdecimal": 65, "kpmultiply": 67, "kpplus": 69, "kpclear": 71, "kpdivide": 75, "kpenter": 76, "kpminus": 78, "kpequals": 81] as [String: CGKeyCode] { codes[k] = v }
let keypadCodes: Set<CGKeyCode> = [82, 83, 84, 85, 86, 87, 88, 89, 91, 92, 65, 67, 69, 71, 75, 76, 78, 81]
let src = CGEventSource(stateID: .hidSystemState)
func key(_ name: String, _ flags: CGEventFlags) {
    guard let code = codes[name] else { FileHandle.standardError.write("drive: unknown key \(name)\n".data(using: .utf8)!); return }
    for down in [true, false] {
        let e = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: down)!
        var f = flags.union(.maskNonCoalesced)
        if code >= 123 { f.insert(.maskSecondaryFn); f.insert(.maskNumericPad) }
        if keypadCodes.contains(code) { f.insert(.maskNumericPad) }
        e.flags = f
        e.post(tap: .cghidEventTap)
        usleep(50_000)
    }
}
var args = Array(CommandLine.arguments.dropFirst())
while !args.isEmpty {
    let a = args.removeFirst()
    if a == "wait" { Thread.sleep(forTimeInterval: Double(args.removeFirst())!); continue }
    // "clearmods": release every modifier (a key posted with modifier flags can leave them latched in the HID
    // state, so the next letter arrives as a control character, 8 Oct 2026).
    // "tap:command" / "tap:option" / "tap:rightOption": a modifier pressed and released alone (the Windows style's
    // Alt, Windows and Applications keys), as flagsChanged events.
    if a.hasPrefix("tap:") {
        let codes: [String: CGKeyCode] = ["command": 55, "option": 58, "rightOption": 61, "control": 59, "shift": 56]
        let flags: [String: CGEventFlags] = ["command": .maskCommand, "option": .maskAlternate, "rightOption": .maskAlternate, "control": .maskControl, "shift": .maskShift]
        let name = String(a.dropFirst(4))
        if let code = codes[name], let flag = flags[name] {
            let down = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: true)!; down.flags = [flag, .maskNonCoalesced]; down.post(tap: .cghidEventTap)
            usleep(80_000)
            let up = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: false)!; up.flags = [.maskNonCoalesced]; up.post(tap: .cghidEventTap)
            usleep(80_000)
        } else { FileHandle.standardError.write("drive: unknown tap \(name)\n".data(using: .utf8)!) }
        continue
    }
    if a == "clearmods" {
        for code: CGKeyCode in [59, 58, 55, 56, 62, 61, 54, 60] {
            let e = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: false)!; e.flags = [.maskNonCoalesced]; e.post(tap: .cghidEventTap); usleep(20_000)
        }
        continue
    }
    // "cmdtab:N": hold Command, press Tab N times, let go: a real app switch (Command up ends the switcher).
    if a.hasPrefix("cmdtab:") {
        let n = Int(a.dropFirst(7)) ?? 1
        let down = CGEvent(keyboardEventSource: src, virtualKey: 55, keyDown: true)!; down.flags = [.maskCommand, .maskNonCoalesced]; down.post(tap: .cghidEventTap)
        usleep(80_000)
        for _ in 0..<n {
            for kd in [true, false] { let e = CGEvent(keyboardEventSource: src, virtualKey: 48, keyDown: kd)!; e.flags = [.maskCommand, .maskNonCoalesced]; e.post(tap: .cghidEventTap); usleep(60_000) }
            usleep(350_000)
        }
        let up = CGEvent(keyboardEventSource: src, virtualKey: 55, keyDown: false)!; up.flags = [.maskNonCoalesced]; up.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.15)
        continue
    }
    // "kp0hold:kp5": keypad 0 held while another keypad key is pressed (the keypad's own modifier).
    if a.hasPrefix("kp0hold:"), let code = codes[String(a.dropFirst(8))] {
        func post(_ c: CGKeyCode, _ d: Bool) { let e = CGEvent(keyboardEventSource: src, virtualKey: c, keyDown: d)!; e.flags = [.maskNumericPad, .maskNonCoalesced]; e.post(tap: .cghidEventTap); usleep(60_000) }
        post(82, true); post(code, true); post(code, false); post(82, false)
        Thread.sleep(forTimeInterval: 0.15)
        continue
    }
    if a.hasPrefix("type:") { for ch in a.dropFirst(5) { key(ch == " " ? "space" : String(ch).lowercased(), ch.isUppercase ? [.maskShift] : []); Thread.sleep(forTimeInterval: 0.12) }; continue }
    var flags: CGEventFlags = []; var name = a
    if a.count > 1, a.contains("+") { let p = a.split(separator: "+").map(String.init); name = p.last!; for m in p.dropLast() { switch m { case "control": flags.insert(.maskControl); case "option": flags.insert(.maskAlternate); case "command": flags.insert(.maskCommand); case "shift": flags.insert(.maskShift); case "fn": flags.insert(.maskSecondaryFn); default: break } } }
    key(name, flags)
    Thread.sleep(forTimeInterval: 0.15)
}
