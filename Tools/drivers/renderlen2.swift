// SPDX-License-Identifier: GPL-3.0-or-later
import AVFoundation
setvbuf(stdout, nil, _IONBF, 0)
let p1 = "Training programmes shall combine theoretical and practical training to develop the technical and behavioural competencies of assessors. Each training programme shall specify the number of assessors targeted, the timeframe for implementation, and the objectives of the training programme. These variables shall be reflected in the approved training programme development form. "
let src = String(repeating: p1, count: 4)
let synth = AVSpeechSynthesizer()
func render(_ id: String, _ text: String) -> Double {
    let u = AVSpeechUtterance(string: text); u.voice = AVSpeechSynthesisVoice(identifier: id); u.rate = 0.6
    var frames = 0.0, rate = 1.0; var fin = false
    synth.write(u) { b in guard let p = b as? AVAudioPCMBuffer else { return }; if p.frameLength == 0 { fin = true; return }; frames += Double(p.frameLength); rate = p.format.sampleRate }
    let t0 = Date(); while !fin && Date().timeIntervalSince(t0) < 60 { RunLoop.main.run(until: Date().addingTimeInterval(0.02)) }
    return frames / rate
}
for id in CommandLine.arguments.dropFirst() {
    // Words one at a time: the sum of sentences approximates the true length.
    var line = "\(id.split(separator: ".").last!):"
    for n in [100, 200, 300, 400, 500, 700, 1000, 1400] {
        let t = String(src.prefix(n))
        line += " \(n)→\(String(format: "%.1f", render(id, t)))s"
    }
    print(line)
}
