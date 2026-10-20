// SPDX-License-Identifier: GPL-3.0-or-later
// Kokoro for TurnOver (12 Oct 2026), the Swift helper that replaced the Python one: the same pipes, nothing else.
// In:  one JSON line per request: {"id": 7, "text": "...", "voice": "bf_emma", "speed": 1.1}, or {"cancel": 7}.
// Out: frames of a 4-byte id, a 4-byte sample count and that many float32 samples (24 kHz mono), a count of 0 ending
//      the request. Logs go to stderr as "kokoro: ..." lines: timings and errors, never the text.
// Ends when its input closes (TurnOver went). The model runs on this Mac; nothing is sent anywhere.
//
// FluidAudio's older seven-stage engine: its "v3" aborted in Metal on macOS 27.2 (M4, 12 Oct 2026), every time.
import Foundation
import FluidAudio

// The audio goes out on a copy of stdout; anything a library prints goes to stderr, never into the audio stream.
let audioFD = dup(1)
dup2(2, 1)
let audioOut = FileHandle(fileDescriptor: audioFD, closeOnDealloc: false)
let outLock = NSLock()

func log(_ s: String) { FileHandle.standardError.write(Data("kokoro: \(s)\n".utf8)) }

func send(_ id: UInt32, _ samples: [Float]) {
    var h = id, n = Int32(samples.count)
    var d = Data(bytes: &h, count: 4); d.append(Data(bytes: &n, count: 4))
    if !samples.isEmpty { samples.withUnsafeBufferPointer { d.append(Data(buffer: $0)) } }
    outLock.lock(); defer { outLock.unlock() }
    do { try audioOut.write(contentsOf: d) } catch { exit(0) }   // TurnOver went
}

struct Request: Sendable { let id: UInt32; let text: String; let voice: String; let speed: Float }

final class Cancelled: @unchecked Sendable {
    private var ids = Set<UInt32>(); private let lock = NSLock()
    func add(_ id: UInt32) { lock.lock(); ids.insert(id); lock.unlock() }
    func has(_ id: UInt32) -> Bool { lock.lock(); defer { lock.unlock() }; return ids.contains(id) }
    func done(_ id: UInt32) { lock.lock(); ids.remove(id); lock.unlock() }
}
let cancelled = Cancelled()

let (requests, continuation) = AsyncStream<Request>.makeStream()

// Reading on its own thread, so a cancel is seen while an utterance is being made.
Thread.detachNewThread {
    while let line = readLine() {
        guard let obj = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any] else { continue }
        if let c = obj["cancel"] as? NSNumber { cancelled.add(c.uint32Value); continue }
        guard let id = (obj["id"] as? NSNumber)?.uint32Value, let text = obj["text"] as? String else { continue }
        let speed = (obj["speed"] as? NSNumber)?.floatValue ?? 1.1
        continuation.yield(Request(id: id, text: text, voice: obj["voice"] as? String ?? "bf_emma", speed: speed > 0 ? speed : 1.1))
    }
    continuation.finish()
    exit(0)
}

/// A sentence at a time, so a long passage starts as quickly as a short one, and the next sentence is being made
/// while the one before plays.
func sentences(_ text: String) -> [String] {
    var parts: [String] = [], cur = ""
    let chars = Array(text)
    for (i, c) in chars.enumerated() {
        cur.append(c)
        if ".!?;:".contains(c), i + 1 < chars.count, chars[i + 1].isWhitespace, cur.count > 1 {
            parts.append(cur.trimmingCharacters(in: .whitespaces)); cur = ""
        }
    }
    let rest = cur.trimmingCharacters(in: .whitespacesAndNewlines)
    if !rest.isEmpty { parts.append(rest) }
    return parts.isEmpty ? [text] : parts
}

/// Kokoro pads every clip with silence: 0.24 to 0.4 s before the first word and 0.4 to 0.7 s after the last
/// (measured 12 Oct 2026), most of the wait that was heard. Cut to 25 ms before and a short pause after: longer
/// between sentences, so reading still breathes.
func trimmed(_ s: [Float], last: Bool) -> [Float] {
    let threshold: Float = 0.004   // low, so a soft first sound (the s of "Send") isn't cut
    guard let on = s.firstIndex(where: { abs($0) > threshold }), let off = s.lastIndex(where: { abs($0) > threshold }) else { return [] }
    let start = max(0, on - 24000 * 25 / 1000)
    let end = min(s.count, off + 24000 * (last ? 60 : 180) / 1000)
    return Array(s[start..<end])
}

/// Short things said again and again (menu items, "button", a letter) come from here, at once.
var cache: [String: [Float]] = [:], cacheOrder: [String] = []
@MainActor func remember(_ key: String, _ s: [Float]) {
    cache[key] = s; cacheOrder.append(key)
    if cacheOrder.count > 400 { cache[cacheOrder.removeFirst()] = nil }
}

// The voice TurnOver will ask for first (its argument), loaded before "ready".
let firstVoice = CommandLine.arguments.dropFirst().first ?? "bf_emma"
let warm = Array(Set([firstVoice, "bf_emma"]))
let manager = KokoroAneManager(version: .legacy)
let t0 = Date()
do { try await manager.initialize(preloadVoices: Set(warm)) }
catch { log("error couldn't load the model: \(error)"); exit(1) }
for v in warm { _ = try? await manager.synthesizeDetailed(text: "Ready.", voice: v) }
log("ready in \(Int(Date().timeIntervalSince(t0) * 1000)) ms")

for await r in requests {
    if cancelled.has(r.id) { send(r.id, []); cancelled.done(r.id); continue }
    let t = Date(); var first = true, cached = false
    let parts = sentences(r.text)
    for (n, part) in parts.enumerated() {
        if cancelled.has(r.id) { break }
        let key = "\(r.voice)|\(r.speed)|\(n == parts.count - 1)|\(part)"
        var samples = cache[key]
        if samples != nil { cached = true } else {
            do { samples = trimmed(try await manager.synthesizeDetailed(text: part, voice: r.voice, speed: r.speed).samples, last: n == parts.count - 1) }
            catch { log("error \(r.id): \(error)"); break }
            if part.count <= 60, let samples { remember(key, samples) }
        }
        guard let samples, !cancelled.has(r.id) else { break }
        if samples.isEmpty { continue }   // nothing to hear; an empty frame would end the request
        send(r.id, samples)
        if first { first = false; log("\(r.id) first audio \(Int(Date().timeIntervalSince(t) * 1000)) ms, \(r.voice)\(cached ? ", remembered" : "")") }
    }
    send(r.id, [])
    cancelled.done(r.id)
}
