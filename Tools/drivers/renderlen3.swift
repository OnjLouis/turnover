// SPDX-License-Identifier: GPL-3.0-or-later
import AVFoundation
setvbuf(stdout, nil, _IONBF, 0)
let p1 = "Training programmes shall combine theoretical and practical training to develop the technical and behavioural competencies of assessors. Each training programme shall specify the number of assessors targeted, the timeframe for implementation, and the objectives of the training programme. These variables shall be reflected in the approved training programme development form."
let synth = AVSpeechSynthesizer()
final class D: NSObject, AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) { print("  delegate didFinish main=\(Thread.isMainThread) at", Date().timeIntervalSince1970) }
}
let d = D(); synth.delegate = d
for id in CommandLine.arguments.dropFirst() {
    let u = AVSpeechUtterance(string: p1); u.voice = AVSpeechSynthesisVoice(identifier: id); u.rate = 0.6
    var frames = 0.0, rate = 1.0, last = Date(), events: [String] = []
    synth.write(u) { b in
        last = Date()
        if let p = b as? AVAudioPCMBuffer { if p.frameLength == 0 { events.append("EMPTY@\(String(format: "%.1f", frames / rate))s t=\(Date().timeIntervalSince1970) main=\(Thread.isMainThread)") } else { frames += Double(p.frameLength); rate = p.format.sampleRate } }
        else { events.append("other:\(type(of: b))") }
    }
    while Date().timeIntervalSince(last) < 1.5 { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }
    print("\(id.split(separator: ".").last!): total \(String(format: "%.1f", frames / rate))s; \(events)")
}
