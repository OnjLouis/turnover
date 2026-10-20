// SPDX-License-Identifier: GPL-3.0-or-later
// wordload: does VoiceOver's own reading of Word slow a second reader's reads?
//
// Three phases, a beep between each, someone arrowing through a long document (about 350,000 characters)
// throughout: VoiceOver speaking; VoiceOver muted by script ("mute speech
// toggle" through its commander); VoiceOver off (the tester presses Cmd+F5).
// In every phase the probe does what the Word reader will do on each
// AXSelectedTextChanged — a bounded line read on the element the notification
// names — and times it, plus a 100 ms "ping" (AXRole on the app element) that
// shows how promptly Word's main thread answers at all.
import Foundation
import ApplicationServices
import TurnOverAX
import AppKit

private struct Phase {
    var name: String
    var notifications = 0
    var lineReadMs: [Double] = []
    var pingMs: [Double] = []
    var periodicLineMs: [Double] = []
    var failures = 0
}

private var current = Phase(name: "lead-in")
private var lastElement: AXUIElement?
private var lastIndex: Int = -1

private func lineRead(_ el: AXUIElement, _ index: Int) -> Double? {
    let t = timed { () -> Bool in
        guard let n = (el.param("AXLineForIndex", index as CFNumber) as? NSNumber)?.intValue,
              let r = cfRange(el.param("AXRangeForLine", n as CFNumber)),
              el.param("AXStringForRange", axRangeValue(r.location, r.length)) is String else { return false }
        return true
    }
    return t.value ? t.ms : nil
}

private let loadCallback: AXObserverCallbackWithInfo = { _, el, name, _, _ in
    let n = name as String
    guard n == "AXSelectedTextChanged" || n == "AXFocusedUIElementChanged" else { return }
    guard el.role == "AXTextArea", let sel = cfRange(el.attr(kAXSelectedTextRangeAttribute)), sel.location != Int.max else { return }
    current.notifications += 1
    lastElement = el; lastIndex = sel.location
    if let ms = lineRead(el, sel.location) { current.lineReadMs.append(ms) } else { current.failures += 1 }
}

/// True when some "Page N content" area reports a real selection.
private func pageAreaHoldsCaret(_ appEl: AXUIElement) -> Bool {
    guard let win = appEl.element(kAXFocusedWindowAttribute) else { return false }
    var queue: [AXUIElement] = [win]; var visited = 0
    while !queue.isEmpty && visited < 6000 {
        let e = queue.removeFirst(); visited += 1
        if e.role == "AXTextArea", (e.string(kAXDescriptionAttribute) ?? "").hasPrefix("Page"),
           let sel = cfRange(e.attr(kAXSelectedTextRangeAttribute)), sel.location != Int.max {
            lastElement = e; lastIndex = sel.location; return true
        }
        queue.append(contentsOf: e.elements(kAXChildrenAttribute))
    }
    return false
}

private func osascript(_ source: String) -> String {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    p.arguments = ["-e", source]
    let out = Pipe(); p.standardOutput = out; p.standardError = out
    try? p.run(); p.waitUntilExit()
    return String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
}

private func voiceOverCommand(_ command: String) -> String {
    osascript("tell application \"VoiceOver\" to tell commander to perform command \"\(command)\"")
}

/// NSSound.beep() is silent from a plain command-line process, so play a
/// system sound file through afplay instead — audible with VoiceOver muted or off.
private func beep(_ times: Int) {
    for _ in 0..<times {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/afplay")
        p.arguments = ["/System/Library/Sounds/Glass.aiff"]
        try? p.run(); p.waitUntilExit()
    }
}

private func report(_ p: Phase) {
    Log.line("=== \(p.name): VoiceOver running \(voiceOverRunning()); caret notifications \(p.notifications), failed reads \(p.failures)")
    Log.line("    " + summarize("line read on notification", p.lineReadMs))
    Log.line("    " + summarize("periodic line read", p.periodicLineMs))
    Log.line("    " + summarize("ping (AXRole of app)", p.pingMs))
}

private func runPhase(_ name: String, seconds: Double, appEl: AXUIElement) {
    current = Phase(name: name)
    let end = Date().addingTimeInterval(seconds)
    var nextTick = Date()
    while Date() < end {
        CFRunLoopRunInMode(.defaultMode, 0.02, true)
        if Date() >= nextTick {
            nextTick = Date().addingTimeInterval(0.1)
            let ping = timed { appEl.attrError(kAXRoleAttribute) }
            current.pingMs.append(ping.ms)
            if let el = lastElement, lastIndex >= 0, let ms = lineRead(el, lastIndex) { current.periodicLineMs.append(ms) }
        }
    }
    report(current)
}

private func waitForVoiceOver(_ wanted: Bool, upTo: Double) -> Bool {
    let end = Date().addingTimeInterval(upTo)
    while Date() < end {
        if voiceOverRunning() == wanted { return true }
        CFRunLoopRunInMode(.defaultMode, 0.25, true)
    }
    return false
}

func runWordLoadGate(_ args: [String]) {
    let opts = Options(args)
    let seconds = opts.double("phase-seconds", 60)
    let lead = opts.double("lead", 25)
    guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.microsoft.Word").first else { Log.line("Word not running"); return }
    let appEl = AXUIElementCreateApplication(app.processIdentifier)
    AXUIElementSetMessagingTimeout(appEl, 3)
    var obs: AXObserver?
    guard AXObserverCreateWithInfoCallback(app.processIdentifier, loadCallback, &obs) == .success, let obs else { Log.line("observer failed"); return }
    for n in ["AXSelectedTextChanged", "AXFocusedUIElementChanged"] { _ = AXObserverAddNotification(obs, appEl, n as CFString, nil) }
    CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(obs), .defaultMode)

    Log.line("lead-in \(Int(lead)) s, then three phases of \(Int(seconds)) s")
    CFRunLoopRunInMode(.defaultMode, lead, false)

    // Do not start the clock until Word is in front and the caret is in the body.
    let ready = Date().addingTimeInterval(180)
    var wasReady = false
    while Date() < ready {
        let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.microsoft.Word"
        let inBody = lastElement != nil || pageAreaHoldsCaret(appEl)
        if front && inBody { wasReady = true; break }
        if Int(Date().timeIntervalSince(ready)) % 10 == 0 { Log.line("waiting: Word frontmost \(front), caret in a page area \(inBody)") }
        CFRunLoopRunInMode(.defaultMode, 1.0, true)
    }
    Log.line(wasReady ? "Word is in front with the caret in the body" : "gave up waiting for Word after 180 s; running anyway")

    beep(1)
    Log.line("beep 1 — phase 1: VoiceOver speaking")
    runPhase("phase 1: VoiceOver speaking", seconds: seconds, appEl: appEl)

    let muted = voiceOverCommand("mute speech toggle")
    Log.line("mute speech toggle -> \"\(muted)\"")
    beep(2)
    Log.line("beep 2 — phase 2: VoiceOver muted by script")
    runPhase("phase 2: VoiceOver muted by script", seconds: seconds, appEl: appEl)
    let unmuted = voiceOverCommand("mute speech toggle")
    Log.line("mute speech toggle (back) -> \"\(unmuted)\"")

    beep(3)
    Log.line("beep 3 — waiting for the owner to turn VoiceOver off (Cmd+F5)")
    if waitForVoiceOver(false, upTo: 90) {
        Log.line("VoiceOver is off — phase 3")
        runPhase("phase 3: VoiceOver off", seconds: seconds, appEl: appEl)
    } else {
        Log.line("VoiceOver did not go off within 90 s; phase 3 skipped")
    }
    beep(4)
    Log.line("beep 4 — waiting for VoiceOver to come back")
    if waitForVoiceOver(true, upTo: 120) { Log.line("VoiceOver is back on") } else { Log.line("VoiceOver still off after 120 s") }
}
