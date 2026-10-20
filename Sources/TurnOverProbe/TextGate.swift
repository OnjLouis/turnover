// SPDX-License-Identifier: GPL-3.0-or-later
// Gate 7: reading text the way the reader will, on a document too big to fetch whole.
//
// The red team's correction: never read AXValue of the whole document on an
// arrow press. AppKit text views expose AXLineForIndex, AXRangeForLine,
// AXStringForRange, AXInsertionPointLineNumber and AXNumberOfCharacters, so a
// "read the current line" is three or four bounded calls. This probe opens a
// 5 MB plain-text file in TextEdit, then simulates 200 down-arrow presses by
// moving the selection one line at a time and reading the line the way the
// reader would, timing every call. It reads AXValue exactly once, at the end,
// to show what that costs by comparison.
//
// It takes the front and makes TextEdit speak under VoiceOver; run it when
// that is acceptable. Threshold: line read p95 <= 30 ms.
import Foundation
import ApplicationServices
import TurnOverAX
import AppKit

func runTextGate(_ args: [String]) {
    let opts = Options(args)
    let lines = opts.int("lines", 200)
    let sizeMB = opts.int("mb", 5)

    // Build the file once.
    let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("TurnOver")
    try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
    let file = support.appendingPathComponent("text-\(sizeMB)mb.txt")
    if !FileManager.default.fileExists(atPath: file.path) {
        var text = ""
        let words = ["reader", "screen", "line", "caret", "table", "focus", "window", "buffer", "marker", "speech", "braille", "review"]
        var n = 0
        while text.utf8.count < sizeMB * 1_000_000 {
            let count = 4 + (n % 9)
            text += (0..<count).map { words[($0 + n) % words.count] }.joined(separator: " ") + " \(n)\n"
            n += 1
        }
        try? text.write(to: file, atomically: true, encoding: .utf8)
        Log.line("wrote \(file.path) (\(text.utf8.count) bytes, \(n) lines)")
    }

    // Open it in TextEdit and wait for the text area to hold the whole file.
    guard let textEditURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.TextEdit") else {
        Log.line("TextEdit not found"); return
    }
    let config = NSWorkspace.OpenConfiguration()
    config.activates = true
    nonisolated(unsafe) var app: NSRunningApplication?   // written once by the callback, read after the wait
    let sema = DispatchSemaphore(value: 0)
    NSWorkspace.shared.open([file], withApplicationAt: textEditURL, configuration: config) { a, e in
        app = a
        if let e { Log.line("open failed: \(e.localizedDescription)") }
        sema.signal()
    }
    while sema.wait(timeout: .now()) != .success { CFRunLoopRunInMode(.defaultMode, 0.05, true) }
    guard let app else { return }
    let appEl = AXUIElementCreateApplication(app.processIdentifier)
    AXUIElementSetMessagingTimeout(appEl, 5)
    Log.line("TextEdit pid \(app.processIdentifier); waiting for the document")

    var area: AXUIElement?
    let expected = (try? FileManager.default.attributesOfItem(atPath: file.path)[.size] as? Int) ?? 0
    let deadline = Date().addingTimeInterval(60)
    while Date() < deadline {
        CFRunLoopRunInMode(.defaultMode, 0.25, true)
        guard let win = appEl.element(kAXFocusedWindowAttribute),
              (win.string(kAXTitleAttribute) ?? "").hasPrefix(file.deletingPathExtension().lastPathComponent),
              let a = win.firstDescendant(role: "AXTextArea") else { continue }
        let n = a.int("AXNumberOfCharacters") ?? 0
        if n >= expected - 10 { area = a; Log.line("document loaded: \(n) characters"); break }
    }
    guard let area else { Log.line("could not find the loaded text area within 60 s"); return }

    // Simulated arrow presses. Each press: set the selection to the start of the
    // next line, then read what a screen reader reads.
    var setMs: [Double] = []
    var rangeForLineMs: [Double] = []
    var stringForRangeMs: [Double] = []
    var lineForIndexMs: [Double] = []
    var insertionLineMs: [Double] = []
    var pressTotalMs: [Double] = []
    var failures = 0
    var lastLineText = ""
    let startLine = 1000  // deep enough that nothing is cached from the initial display
    for i in 0..<lines {
        let line = startLine + i
        let t0 = DispatchTime.now().uptimeNanoseconds
        let r = timed { area.paramError("AXRangeForLine", line as CFNumber) }
        rangeForLineMs.append(r.ms)
        guard let range = cfRange(r.value.0) else { failures += 1; Log.line("line \(line): AXRangeForLine \(describeError(r.value.1))"); continue }
        let s = timed { area.set(kAXSelectedTextRangeAttribute, axRangeValue(range.location, 0)) }
        setMs.append(s.ms)
        let str = timed { area.paramError("AXStringForRange", axRangeValue(range.location, range.length)) }
        stringForRangeMs.append(str.ms)
        let lfi = timed { area.paramError("AXLineForIndex", range.location as CFNumber) }
        lineForIndexMs.append(lfi.ms)
        let ipl = timed { area.attrError("AXInsertionPointLineNumber") }
        insertionLineMs.append(ipl.ms)
        pressTotalMs.append(Double(DispatchTime.now().uptimeNanoseconds - t0) / 1_000_000)
        if let text = str.value.0 as? String { lastLineText = text } else { failures += 1 }
        if i < 2 {
            Log.line("line \(line): range \(range.location)+\(range.length), text \"\(lastLineText.trimmingCharacters(in: .newlines))\", AXLineForIndex -> \((lfi.value.0 as? NSNumber)?.intValue ?? -1), insertion line \((ipl.value.0 as? NSNumber)?.intValue ?? -1)")
        }
    }
    Log.line(summarize("per-press total (set + 3 reads)", pressTotalMs))
    Log.line(summarize("set AXSelectedTextRange", setMs))
    Log.line(summarize("AXRangeForLine", rangeForLineMs))
    Log.line(summarize("AXStringForRange", stringForRangeMs))
    Log.line(summarize("AXLineForIndex", lineForIndexMs))
    Log.line(summarize("AXInsertionPointLineNumber", insertionLineMs))
    Log.line("failures: \(failures)")

    // The thing not to do, once, for contrast.
    let value = timed { area.attrError(kAXValueAttribute) }
    let len = (value.value.0 as? String)?.utf16.count ?? -1
    Log.line(String(format: "AXValue of the whole document: %d UTF-16 units in %.1f ms (%@)", len, value.ms, describeError(value.value.1)))
    let count = timed { area.int("AXNumberOfCharacters") ?? -1 }
    Log.line(String(format: "AXNumberOfCharacters: %d in %.2f ms", count.value, count.ms))

    let p95 = pressTotalMs.sorted()[min(pressTotalMs.count - 1, Int(Double(pressTotalMs.count) * 0.95))]
    Log.line("Verdict: per-press p95 \(String(format: "%.1f", p95)) ms against a 30 ms threshold: \(p95 <= 30 ? "PASS" : "FAIL")")

    if !opts.has("keep") {
        app.terminate()
        Log.line("TextEdit closed")
    }
}
