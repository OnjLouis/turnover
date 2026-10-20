// SPDX-License-Identifier: GPL-3.0-or-later
// Gate 6: the speech engine, silently.
//
// The reader will not let AVSpeechSynthesizer play audio itself; it takes the
// PCM through write(_:toBufferCallback:toMarkerCallback:) and mixes it on its
// own AVAudioEngine, so it can cut speech within a buffer and mix earcons. This
// probe drives that same path and never plays a sample, so it can run while
// VoiceOver is in use. It measures, per voice:
//
//   - time from write() to the first non-empty buffer (cold, then warm),
//   - gaps between consecutive buffers inside one utterance (a stall is > 250 ms),
//   - whether a zero-length buffer arrives before the utterance is finished
//     (macOS 27 is reported to do this ~15 s into long text),
//   - whether word markers arrive and how far behind the audio they sit,
//   - how long stopSpeaking(.immediate) takes to stop buffers arriving,
//   - a 3,000-word Say All in one utterance.
//
// It also shows whether VoiceOver's own speech is disturbed: the owner's ears
// decide that, and the log says exactly when each utterance started.
import Foundation
import AVFoundation

nonisolated private final class SpeechRun: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {   // the probe's run loop only
    let synth = AVSpeechSynthesizer()
    var finished = false
    var cancelled = false
    var buffers = 0
    var frames = 0
    var zeroLengthMid = 0
    var sawZeroLength = false
    var firstAudioMs: Double?
    var lastBufferAt: Date?
    var start = Date()
    var gaps: [Double] = []
    var markers = 0
    var markerLagMs: [Double] = []
    var sampleRate: Double = 0

    override init() {
        super.init()
        synth.delegate = self
    }

    func speak(_ text: String, voice: AVSpeechSynthesisVoice, rate: Float) {
        finished = false; cancelled = false; buffers = 0; frames = 0; zeroLengthMid = 0; sawZeroLength = false
        firstAudioMs = nil; lastBufferAt = nil; gaps = []; markers = 0; markerLagMs = []
        let u = AVSpeechUtterance(string: text)
        u.voice = voice
        u.rate = rate
        start = Date()
        if #available(macOS 13.0, *) {
            synth.write(u, toBufferCallback: { [weak self] buffer in
                self?.gotBuffer(buffer)
            }, toMarkerCallback: { [weak self] marks in
                self?.gotMarkers(marks)
            })
        } else {
            synth.write(u) { [weak self] buffer in self?.gotBuffer(buffer) }
        }
    }

    private func gotBuffer(_ buffer: AVAudioBuffer) {
        let now = Date()
        guard let pcm = buffer as? AVAudioPCMBuffer else { return }
        sampleRate = pcm.format.sampleRate
        if pcm.frameLength == 0 {
            sawZeroLength = true
            return
        }
        if sawZeroLength { zeroLengthMid += 1 }   // audio after an empty buffer: the macOS 27 bug shape
        buffers += 1
        frames += Int(pcm.frameLength)
        if firstAudioMs == nil { firstAudioMs = now.timeIntervalSince(start) * 1000 }
        if let last = lastBufferAt { gaps.append(now.timeIntervalSince(last) * 1000) }
        lastBufferAt = now
    }

    @available(macOS 13.0, *)
    private func gotMarkers(_ marks: [AVSpeechSynthesisMarker]) {
        for m in marks where m.mark == .word {
            markers += 1
            // How far ahead of delivered audio the marker sits (frames -> ms).
            if sampleRate > 0 {
                markerLagMs.append((Double(m.byteSampleOffset) - Double(frames)) / sampleRate * 1000)
            }
        }
    }

    func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) { finished = true }
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) { cancelled = true; finished = true }

    func waitUntilDone(timeout: Double) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !finished && Date() < deadline {
            CFRunLoopRunInMode(.defaultMode, 0.01, true)
        }
        return finished
    }

    var audioMs: Double { sampleRate > 0 ? Double(frames) / sampleRate * 1000 : 0 }
    var audioMsAtStop: Double = 0
}

private let shortPhrases = [
    "Inbox, 14 messages", "Reply", "Sent", "Table, 3 rows", "link, AppleVis", "heading level 2, Bugs",
    "checkbox, unchecked", "edit text", "Finder", "Documents folder, 12 items", "button, Cancel",
    "The quick brown fox jumps over the lazy dog", "menu, File", "Safari", "search field",
]

func runVoicesGate(_ args: [String]) {
    let voices = AVSpeechSynthesisVoice.speechVoices()
    Log.line("\(voices.count) voices")
    for v in voices.sorted(by: { $0.identifier < $1.identifier }) {
        Log.line("\(v.identifier)  \(v.name)  \(v.language)  quality \(v.quality.rawValue)")
    }
}

func runSpeechGate(_ args: [String]) {
    let opts = Options(args)
    let count = opts.int("count", 200)
    let wanted = opts.string("voice")
    let rate = Float(opts.double("rate", 0.9))

    let all = AVSpeechSynthesisVoice.speechVoices()
    var picks: [AVSpeechSynthesisVoice] = []
    if let wanted {
        picks = all.filter { $0.identifier.localizedCaseInsensitiveContains(wanted) || $0.name.localizedCaseInsensitiveContains(wanted) }
    } else {
        // Default set: an Eloquence voice, Alex, and a compact voice.
        if let e = all.first(where: { $0.identifier.contains("eloquence.en-GB.Reed") }) ?? all.first(where: { $0.identifier.contains("eloquence.en") }) { picks.append(e) }
        if let a = all.first(where: { $0.identifier == "com.apple.voice.enhanced.en-US.Alex" || $0.name == "Alex" }) { picks.append(a) }
        if let c = all.first(where: { $0.identifier.contains("compact.en-GB.Daniel") }) ?? all.first(where: { $0.identifier.contains("compact.en") }) { picks.append(c) }
    }
    guard !picks.isEmpty else { Log.line("No matching voice"); return }

    let run = SpeechRun()
    for voice in picks {
        Log.line("=== Voice \(voice.identifier) (\(voice.name)) rate \(rate)")

        // Cold start.
        run.speak("Ready", voice: voice, rate: rate)
        let coldDone = run.waitUntilDone(timeout: 10)
        Log.line(String(format: "cold: first audio %.0f ms, %d buffers, %.0f ms audio, finished %@",
                        run.firstAudioMs ?? -1, run.buffers, run.audioMs, coldDone ? "yes" : "NO"))

        // Warm short utterances, the typing-echo and focus-change shape.
        var firsts: [Double] = []
        var stalls = 0
        var zeroMid = 0
        var unfinished = 0
        var allGaps: [Double] = []
        var markerTotal = 0
        var markerLags: [Double] = []
        let t0 = Date()
        for i in 0..<count {
            run.speak(shortPhrases[i % shortPhrases.count], voice: voice, rate: rate)
            if !run.waitUntilDone(timeout: 5) { unfinished += 1 }
            if let f = run.firstAudioMs { firsts.append(f) }
            stalls += run.gaps.filter { $0 > 250 }.count
            allGaps.append(contentsOf: run.gaps)
            zeroMid += run.zeroLengthMid
            markerTotal += run.markers
            markerLags.append(contentsOf: run.markerLagMs)
        }
        Log.line(String(format: "warm x%d in %.1f s: %@", count, Date().timeIntervalSince(t0), summarize("first audio", firsts)))
        Log.line("warm: \(summarize("inter-buffer gap", allGaps)); stalls>250ms \(stalls); zero-length buffers before finish \(zeroMid); unfinished \(unfinished); word markers \(markerTotal); \(summarize("marker offset ahead of delivered audio", markerLags))")

        // Cancel latency: start a long sentence, stop after 150 ms, see when buffers stop.
        run.speak(String(repeating: "This sentence keeps going so that it can be interrupted. ", count: 20), voice: voice, rate: rate)
        let cancelDeadline = Date().addingTimeInterval(0.15)
        while Date() < cancelDeadline { CFRunLoopRunInMode(.defaultMode, 0.005, true) }
        let buffersAtStop = run.buffers
        run.audioMsAtStop = run.audioMs
        let stopAt = Date()
        run.synth.stopSpeaking(at: .immediate)
        var lastArrival = stopAt
        let settle = Date().addingTimeInterval(1.0)
        while Date() < settle {
            CFRunLoopRunInMode(.defaultMode, 0.005, true)
            if run.buffers != buffersAtStop, let l = run.lastBufferAt { lastArrival = l }
        }
        Log.line(String(format: "cancel: %d buffers (%.0f ms audio) before stop, %d after, last arrival %.0f ms after stop, didCancel %@, finished %@",
                        buffersAtStop, run.audioMsAtStop, run.buffers - buffersAtStop, lastArrival.timeIntervalSince(stopAt) * 1000,
                        run.cancelled ? "yes" : "no", run.finished ? "yes" : "no"))

        // Say All: ~3,000 words in one utterance.
        if opts.has("sayall") {
            let words = (0..<3000).map { shortPhrases[$0 % shortPhrases.count].split(separator: " ")[0] }
            let text = words.joined(separator: " ")
            run.speak(text, voice: voice, rate: rate)
            let sayAllDone = run.waitUntilDone(timeout: 600)
            Log.line(String(format: "say all: %d buffers, %.1f s of audio, first %.0f ms, %@; stalls>250ms %d; zero-length mid-utterance %d; word markers %d; finished %@",
                            run.buffers, run.audioMs / 1000, run.firstAudioMs ?? -1, summarize("gap", run.gaps),
                            run.gaps.filter { $0 > 250 }.count, run.zeroLengthMid, run.markers, sayAllDone ? "yes" : "NO"))
        }
    }
}
