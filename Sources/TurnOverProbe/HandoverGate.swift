// SPDX-License-Identifier: GPL-3.0-or-later
// Gate 10: the hand-over between VoiceOver and the reader, by script.
//
// Off: `tell application "VoiceOver" to quit` (its dictionary has quit), with a
// fallback of pressing the owner's own toggle shortcut through System Events.
// On: relaunch VoiceOver by bundle identifier. Both are timed against
// NSWorkspace.isVoiceOverEnabled, and after the quit the probe watches for
// three seconds to see whether launchd brings VoiceOver straight back, which
// would make the quit route useless. The reader's voice narrates each step.
import Foundation
import AppKit
import TurnOverSpeech

private func shell(_ path: String, _ args: [String]) -> (String, Int32) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: path)
    p.arguments = args
    let out = Pipe(); p.standardOutput = out; p.standardError = out
    try? p.run(); p.waitUntilExit()
    let text = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return (text, p.terminationStatus)
}

private func waitVoiceOver(_ wanted: Bool, upTo: Double) -> Double? {
    let start = Date()
    while Date().timeIntervalSince(start) < upTo {
        if voiceOverRunning() == wanted { return Date().timeIntervalSince(start) }
        CFRunLoopRunInMode(.defaultMode, 0.05, true)
    }
    return nil
}

/// Post the toggle shortcut (Option + keyCode) at the HID level, as a physical
/// press would arrive. Modifier down, key down, key up, modifier up.
private func postToggleShortcut(keyCode: CGKeyCode) {
    let src = CGEventSource(stateID: .hidSystemState)
    let optionCode = CGKeyCode(58)
    let seq: [(CGKeyCode, Bool, CGEventFlags)] = [
        (optionCode, true, .maskAlternate), (keyCode, true, .maskAlternate),
        (keyCode, false, .maskAlternate), (optionCode, false, []),
    ]
    for (code, down, flags) in seq {
        guard let e = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: down) else { continue }
        e.flags = flags
        e.post(tap: .cghidEventTap)
        usleep(20_000)
    }
    Log.line("posted Option+key \(keyCode) at the HID tap")
}

func runHandoverGate(_ args: [String]) {
    let opts = Options(args)
    let toggleKeyCode = opts.int("keycode", 39)   // apostrophe, for an Option-apostrophe toggle; pass the user's own with --keycode
    let player: SpeechPlayer
    do { player = try SpeechPlayer(voice: "com.apple.eloquence.en-GB.Reed", rate: 0.55) } catch { Log.line("player failed: \(error)"); return }
    func say(_ s: String) { player.speak(s); Log.line("say: \(s)") }

    guard voiceOverRunning() else { Log.line("VoiceOver is not running; start it first"); return }
    say("Handing over in three seconds.")
    CFRunLoopRunInMode(.defaultMode, 3.0, false)

    // Route A: press the owner's toggle shortcut as a HID-level event (System
    // Events' key code did nothing; symbolic hotkeys want a real-looking event).
    var offVia = "HID-level Option+key \(toggleKeyCode)"
    postToggleShortcut(keyCode: CGKeyCode(toggleKeyCode))
    var offAfter = waitVoiceOver(false, upTo: 5)
    if offAfter == nil {
        // Route B: the preference the toggle itself writes.
        offVia = "defaults write voiceOverOnOffKey false"
        let (out, status) = shell("/usr/bin/defaults", ["write", "com.apple.universalaccess", "voiceOverOnOffKey", "-bool", "false"])
        Log.line("defaults write voiceOverOnOffKey false: status \(status) \"\(out)\"")
        offAfter = waitVoiceOver(false, upTo: 5)
    }
    guard let off = offAfter else {
        Log.line("VoiceOver did not go off by either route"); say("VoiceOver did not go off. Test over."); CFRunLoopRunInMode(.defaultMode, 3, false); return
    }
    Log.line(String(format: "VoiceOver off %.0f ms after: %@", off * 1000, offVia))
    say("VoiceOver is off. TurnOver speaking.")
    if let back = waitVoiceOver(true, upTo: 3) {
        Log.line(String(format: "VoiceOver relaunched itself %.0f ms later", back * 1000))
        say("VoiceOver came back by itself.")
        CFRunLoopRunInMode(.defaultMode, 3, false)
        return
    }
    Log.line("VoiceOver stayed off for 3 s")

    say("Bringing VoiceOver back.")
    CFRunLoopRunInMode(.defaultMode, 1.5, false)
    var onVia = "HID-level Option+key \(toggleKeyCode)"
    postToggleShortcut(keyCode: CGKeyCode(toggleKeyCode))
    var onAfter = waitVoiceOver(true, upTo: 6)
    if onAfter == nil {
        onVia = "defaults write true + open -b com.apple.VoiceOver"
        let (out, status) = shell("/usr/bin/defaults", ["write", "com.apple.universalaccess", "voiceOverOnOffKey", "-bool", "true"])
        Log.line("defaults write voiceOverOnOffKey true: status \(status) \"\(out)\"")
        let (o2, s2) = shell("/usr/bin/open", ["-b", "com.apple.VoiceOver"])
        Log.line("open -b com.apple.VoiceOver: status \(s2) \"\(o2)\"")
        onAfter = waitVoiceOver(true, upTo: 6)
    }
    if let on = onAfter {
        Log.line(String(format: "VoiceOver back on %.0f ms after: %@", on * 1000, onVia))
        Log.line("Verdict: hand-over works, off via \(offVia), on via \(onVia)")
    } else {
        Log.line("VoiceOver did not come back by either route — press your toggle")
        say("VoiceOver did not come back. Press your toggle.")
    }
    CFRunLoopRunInMode(.defaultMode, 2.0, false)
}
