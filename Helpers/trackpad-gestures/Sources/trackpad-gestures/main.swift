// SPDX-License-Identifier: GPL-3.0-or-later
// trackpad-gestures: Trackpad gestures' program, for TurnOver (github.com/TurnOver-For-Mac/turnover-plugins). MIT.
//
// What it does, all of it:
//  1. Reads the fingers on the Mac's trackpad through Apple's MultitouchSupport (private: a macOS update may change
//     it, which is why this is a separate program, not part of TurnOver). Only positions: no keys, no screen.
//  2. Tells VoiceOver's trackpad gestures apart (Recogniser.swift): taps, double and triple taps, flicks, the
//     two-finger turn a step at a time, the two-finger scrub, and one finger resting to explore.
//  3. Plays the trackpad's haptics when TurnOver asks (the finger must be on the trackpad to feel them).
// It can't do anything else: TurnOver starts it without TurnOver's permissions; it has no network, reads no files.
// The pointer, clicks and scrolling are held back by TurnOver itself while trackpad control is on, not here.
//
// Talking to TurnOver, one line each way. It writes:
//   G <gesture> <fingers>   tap, double-tap, triple-tap, flick-left/right/up/down, scrub
//   R cw | R ccw            one step of a two-finger turn
//   E <x> <y> | E end       exploring: where the resting finger is (0 to 1 across, 0 to 1 up), and when it lifts
//   L <text>                a line for TurnOver's log
// It reads: "H tick", "H bump", "H double", "H light" (a haptic), "quit". When its input closes, it quits.
//
//   trackpad-gestures              run
//   trackpad-gestures --self-test  checks the recogniser with made-up touches
import AppKit
import Foundation

setvbuf(stdout, nil, _IOLBF, 0)
func out(_ s: String) { print(s.replacingOccurrences(of: "\n", with: " ")) }

if CommandLine.arguments.contains("--self-test") { exit(SelfTest.run()) }

// MARK: - The fingers

typealias MTDeviceRef = UnsafeMutableRawPointer
typealias Callback = @convention(c) (MTDeviceRef?, UnsafeMutableRawPointer?, Int32, Double, Int32) -> Int32
guard let mt = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_NOW) else {
    out("L MultitouchSupport is missing: no trackpad gestures on this Mac"); exit(2)
}
func sym<T>(_ n: String, _ t: T.Type) -> T? { dlsym(mt, n).map { unsafeBitCast($0, to: t) } }
guard let createList = sym("MTDeviceCreateList", (@convention(c) () -> Unmanaged<CFArray>?).self),
      let register = sym("MTRegisterContactFrameCallback", (@convention(c) (MTDeviceRef, Callback) -> Void).self),
      let startDevice = sym("MTDeviceStart", (@convention(c) (MTDeviceRef, Int32) -> Void).self) else {
    out("L MultitouchSupport has changed: no trackpad gestures (a macOS update?)"); exit(2)
}

let recogniser = Recogniser()
/// A double-tap carries where it was: "G double-tap 2 0.512 0.930".
func emit(_ g: Gesture) {
    if case .doubleTap = g { out(g.line + String(format: " %.3f %.3f", recogniser.lastTapAt.0, recogniser.lastTapAt.1)) } else { out(g.line) }
}
// The contact layout the community has used for years: 96 bytes each; identifier at 16, state at 20, normalised
// position at 32 and 36. States 3 to 5 are a finger making, holding and breaking contact.
let contactSize = 96
let frameCallback: Callback = { _, data, n, timestamp, _ in
    var fingers: [Finger] = []
    if let data, n > 0, n < 12 {
        for i in 0..<Int(n) {
            let p = data.advanced(by: i * contactSize)
            let state = p.load(fromByteOffset: 20, as: Int32.self)
            guard (3...5).contains(state) else { continue }
            let x = p.load(fromByteOffset: 32, as: Float.self), y = p.load(fromByteOffset: 36, as: Float.self)
            guard (0...1).contains(x), (0...1).contains(y) else { continue }
            fingers.append(Finger(id: p.load(fromByteOffset: 16, as: Int32.self), x: x, y: y))
        }
    }
    // One clock for frames and the tap timer (the frame's own timestamp is the device's).
    DispatchQueue.main.async { for g in recogniser.frame(fingers, at: ProcessInfo.processInfo.systemUptime) { emit(g) } }
    return 0
}
let devices = (createList()?.takeRetainedValue() as? [AnyObject]) ?? []
if devices.isEmpty { out("L no trackpad found"); exit(2) }
for d in devices {
    let ref = Unmanaged.passUnretained(d).toOpaque()
    register(ref, frameCallback)
    startDevice(ref, 0)
}
out("L reading \(devices.count) trackpad\(devices.count == 1 ? "" : "s")")
// A tap is only known once no second tap can follow: look for those every 50 ms.
Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
    for g in recogniser.flushTaps(at: ProcessInfo.processInfo.systemUptime) { emit(g) }
}

// MARK: - Haptics

let haptics = Haptics()
haptics.open()

// MARK: - Commands from TurnOver

var pending = Data()
FileHandle.standardInput.readabilityHandler = { h in
    let d = h.availableData
    DispatchQueue.main.async {
        if d.isEmpty { exit(0) }
        pending.append(d)
        while let nl = pending.firstIndex(of: 0x0A) {
            let line = String(decoding: pending[pending.startIndex..<nl], as: UTF8.self).trimmingCharacters(in: .whitespaces)
            pending.removeSubrange(pending.startIndex...nl)
            if line == "quit" { exit(0) }
            if line.hasPrefix("H ") { haptics.play(String(line.dropFirst(2))) }
        }
    }
}
signal(SIGTERM, SIG_DFL)
RunLoop.main.run()
