// SPDX-License-Identifier: GPL-3.0-or-later
import AVFoundation
setvbuf(stdout, nil, _IONBF, 0)
let p1 = "Training programmes shall combine theoretical and practical training to develop the technical and behavioural competencies of assessors. Each training programme shall specify the number of assessors targeted, the timeframe for implementation, and the objectives of the training programme. These variables shall be reflected in the approved training programme development form."
let long = String(repeating: p1 + " ", count: 3)
let synth = AVSpeechSynthesizer()
let ids = CommandLine.arguments.dropFirst()
for id in ids {
  for text in [String(p1.prefix(60)), p1, long] {
    let u = AVSpeechUtterance(string: text)
    u.voice = AVSpeechSynthesisVoice(identifier: id); u.rate = 0.6
    var frames = 0.0, n = 0, rate = 0.0
    let done = DispatchSemaphore(value: 0)
    synth.write(u) { b in
        guard let p = b as? AVAudioPCMBuffer else { return }
        if p.frameLength == 0 { done.signal(); return }
        frames += Double(p.frameLength); n += 1; rate = p.format.sampleRate
    }
    let t0 = Date(); while done.wait(timeout: .now()) == .timedOut && Date().timeIntervalSince(t0) < 60 { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }
    print("\(id.split(separator: ".").last!) \(text.count) chars → \(String(format: "%.1f", frames / max(rate, 1))) s in \(n) buffers at \(rate) Hz; \(String(format: "%.1f", Double(text.count) / max(frames / max(rate,1), 0.01))) chars/s")
  }
}
