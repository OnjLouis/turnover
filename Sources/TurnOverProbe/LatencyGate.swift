// SPDX-License-Identifier: GPL-3.0-or-later
// Gate 5: keypress to first audio, on the reader's own speech path.
//
// VoiceOver must be off. An active tap swallows every key you type (so nothing
// lands in an app) and echoes it through SpeechPlayer; for each key the log
// records event time → speak() call → first buffer scheduled, plus the output
// path's latency (device presentation latency + one hardware buffer), which
// is what stands between the scheduled buffer and your ear. Escape ends it.
import Foundation
import CoreGraphics
import Carbon.HIToolbox
import TurnOverSpeech

private var latencyPlayer: SpeechPlayer?
private var latencyFinished = false
private var eventToSpeakMs: [Double] = []
private var speakToBufferMs: [Double] = []
private var totalMs: [Double] = []
private var echoed = 0

private func nsToMach(_ ns: UInt64) -> UInt64 { UInt64(Double(ns) / SpeechPlayer.machToNs) }

private let latencyTap: CGEventTapCallBack = { _, type, event, refcon in
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let refcon { CGEvent.tapEnable(tap: Unmanaged<CFMachPort>.fromOpaque(refcon).takeUnretainedValue(), enable: true) }
        return Unmanaged.passUnretained(event)
    }
    let code = event.getIntegerValueField(.keyboardEventKeycode)
    if type == .keyDown {
        if code == 53 { latencyFinished = true; return nil }
        // The event's timestamp is nanoseconds on the mach clock; convert to ticks.
        let eventAt = nsToMach(event.timestamp)
        let speakAt = mach_absolute_time()
        eventToSpeakMs.append(Double(speakAt &- eventAt) * SpeechPlayer.machToNs / 1_000_000)
        var length = 0
        var chars = [UniChar](repeating: 0, count: 4)
        event.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &length, unicodeString: &chars)
        var name = String(utf16CodeUnits: chars, count: length)
        if name == " " { name = "space" } else if name.isEmpty || name.unicodeScalars.contains(where: { $0.value < 32 }) { name = "key" }
        echoed += 1
        latencyPlayer?.speak(name, interrupt: true, requestedAt: eventAt)
        return nil
    }
    if type == .keyUp { return nil }
    return Unmanaged.passUnretained(event)
}

func runLatencyGate(_ args: [String]) {
    let opts = Options(args)
    let maxSeconds = opts.double("seconds", 180)
    let voiceId = opts.string("voice") ?? "com.apple.eloquence.en-GB.Reed"

    let player: SpeechPlayer
    do { player = try SpeechPlayer(voice: voiceId, rate: 0.55, bufferFrames: UInt32(opts.int("frames", 128))) }
    catch { Log.line("SpeechPlayer failed: \(error)"); return }
    latencyPlayer = player
    Log.line(String(format: "player: %.0f Hz, buffer %d frames, output latency %.2f ms", player.sampleRate, player.bufferFrames, player.outputLatencySeconds * 1000))
    player.onFirstAudio = { timing in
        if let total = timing.requestToFirstBufferMs {
            totalMs.append(total)
            let evToSpeak = eventToSpeakMs.last ?? 0
            speakToBufferMs.append(total - evToSpeak)
            Log.line(String(format: "echo \"%@\": event→speak %.2f ms, speak→first buffer %.2f ms, total to scheduled %.2f ms (+%.2f ms output path)",
                            timing.text, evToSpeak, total - evToSpeak, total, player.outputLatencySeconds * 1000))
        }
    }

    // Warm the engine once so the first echo is not the cold path.
    player.speak("TurnOver latency test. Turn VoiceOver off to begin.")
    var reminded = Date()
    let waitEnd = Date().addingTimeInterval(180)
    while voiceOverRunning() && Date() < waitEnd {
        if Date().timeIntervalSince(reminded) > 15 { player.speak("Turn VoiceOver off to begin."); reminded = Date() }
        CFRunLoopRunInMode(.defaultMode, 0.5, true)
    }
    guard !voiceOverRunning() else { Log.line("VoiceOver stayed on; not starting"); return }
    // Discard the warm-up measurements.
    eventToSpeakMs.removeAll(); speakToBufferMs.removeAll(); totalMs.removeAll()

    let mask = CGEventMask(1 << CGEventType.keyDown.rawValue | 1 << CGEventType.keyUp.rawValue)
    guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                      eventsOfInterest: mask, callback: latencyTap, userInfo: nil) else {
        Log.line("could not create the tap"); player.speak("Could not create the event tap."); return
    }
    CFRunLoopAddSource(CFRunLoopGetCurrent(), CFMachPortCreateRunLoopSource(nil, tap, 0), .defaultMode)
    Log.line("VoiceOver off, tap up — echoing keys")
    player.speak("Ready. Type letters at your normal speed. Every key is swallowed and echoed. Press Escape to finish.")

    let end = Date().addingTimeInterval(maxSeconds)
    while !latencyFinished && Date() < end { CFRunLoopRunInMode(.defaultMode, 0.02, true) }
    CGEvent.tapEnable(tap: tap, enable: false)

    Log.line("keys echoed: \(echoed)")
    Log.line(summarize("event → speak() call", eventToSpeakMs))
    Log.line(summarize("speak() → first buffer scheduled", speakToBufferMs))
    Log.line(summarize("event → first buffer scheduled", totalMs))
    Log.line(String(format: "add the output path: %.2f ms (presentation latency + one %d-frame buffer)", player.outputLatencySeconds * 1000, player.bufferFrames))
    if !totalMs.isEmpty {
        let s = totalMs.sorted(); let p95 = s[min(s.count - 1, Int(Double(s.count) * 0.95))] + player.outputLatencySeconds * 1000
        Log.line(String(format: "Verdict: key to ear p95 ≈ %.1f ms against 80 ms: %@", p95, p95 <= 80 ? "PASS" : "FAIL"))
    }
    player.speak("Finished. Turn VoiceOver back on.")
    CFRunLoopRunInMode(.defaultMode, 3.0, false)
}
