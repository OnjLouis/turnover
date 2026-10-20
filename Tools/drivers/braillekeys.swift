// SPDX-License-Identifier: GPL-3.0-or-later
// Guided key recording for a BAUM display: speaks a prompt, records the reports that follow, labelled.
import Foundation
import IOKit.hid
import AVFoundation
setvbuf(stdout, nil, _IONBF, 0)
let synth = AVSpeechSynthesizer()
func say(_ s: String) { let u = AVSpeechUtterance(string: s); u.rate = 0.55; synth.speak(u) }
let m = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
IOHIDManagerSetDeviceMatching(m, [kIOHIDVendorIDKey: 0x0904] as CFDictionary)
IOHIDManagerScheduleWithRunLoop(m, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
IOHIDManagerOpen(m, IOOptionBits(kIOHIDOptionsTypeNone))
guard let devs = IOHIDManagerCopyDevices(m) as? Set<IOHIDDevice>, let d = devs.first else { print("no display"); exit(1) }
var label = "start"
IOHIDDeviceRegisterInputReportCallback(d, UnsafeMutablePointer<UInt8>.allocate(capacity: 64), 64, { _, _, _, _, id, r, n in
    print("[\(label)] " + (0..<n).map { String(format: "%02x", r[$0]) }.joined(separator: " "))
}, nil)
func send(_ b: [UInt8]) { var r = b; if r.count < 21 { r += Array(repeating: 0, count: 21 - r.count) }; _ = r.withUnsafeBufferPointer { IOHIDDeviceSetReport(d, kIOHIDReportTypeOutput, 0, $0.baseAddress!, $0.count) } }
func cell(_ dots: String) -> UInt8 { dots.reduce(0) { $0 | (1 << (($1.wholeNumberValue ?? 1) - 1)) } }
// The start-up questions a screen reader asks (BRLTTY's probe): serial number, identity, cell count, keys now.
label = "init"
for q: [UInt8] in [[0x8A], [0x84], [0x01, 0x00], [0x08]] { send(q); RunLoop.main.run(until: Date().addingTimeInterval(0.4)) }
send([0x01] + ["2345","136","1235","1345","135","1236","15","1235","","2345","15","234","2345","","78","78","78","78","78","78"].map(cell))
func wait(_ s: Double) { RunLoop.main.run(until: Date().addingTimeInterval(s)) }
let steps: [(String, String, Double)] = [
    ("display", "Is the display showing turnover test? Leave it a moment. Then, starting now, press each key above or beside the braille cells, one at a time, from left to right, with a pause between each.", 26),
    ("routing-first", "Now press the routing key above the first cell, once.", 9),
    ("routing-last", "Now the routing key above the last cell, once.", 9),
    ("joystick", "Now the joystick, if it has one: up, then down, then left, then right, then press it in. Pause between each.", 22),
    ("front", "Now any keys along the front edge or thumb keys, left to right, pausing between each.", 20),
    ("dots", "Now the braille keyboard: dot 1, dot 2, dot 3, dot 4, dot 5, dot 6, dot 7, dot 8, then space, one at a time.", 30),
]
for (l, prompt, secs) in steps {
    label = l + "-prompt"; print("== \(l)")
    say(prompt)
    while synth.isSpeaking { wait(0.1) }
    label = l
    wait(secs)
}
say("That's all, thank you.")
while synth.isSpeaking { wait(0.1) }
send([0x01] + Array(repeating: 0, count: 20))
print("done")
