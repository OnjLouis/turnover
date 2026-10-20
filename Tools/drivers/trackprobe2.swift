// SPDX-License-Identifier: GPL-3.0-or-later
// trackprobe2: step 3 of the trackpad work (the roadmap core 1). Reads finger positions from Apple's private
// MultitouchSupport and tells VoiceOver's Trackpad Commander gestures apart: taps (1, 2 fingers, single and double),
// flicks (1, 2 fingers, four directions), two-finger rotation (the rotor). Read-only: it only listens; the pointer
// and the Mac's own gestures keep working. Says each gesture it recognises with the Mac's say command, and ends by
// itself after 60 s (dead-man), or with Control C.
//
// The contact layout (96 bytes each) is the one the community has used for years (OpenMultitouchSupport and
// others): normalised position at 32, state at 20, identifier at 16. The probe prints a check of it first.
import Foundation

typealias MTDeviceRef = UnsafeMutableRawPointer
typealias Callback = @convention(c) (MTDeviceRef?, UnsafeMutableRawPointer?, Int32, Double, Int32) -> Int32
guard let h = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_NOW) else { print("no MultitouchSupport"); exit(1) }
func sym<T>(_ n: String, _ t: T.Type) -> T? { dlsym(h, n).map { unsafeBitCast($0, to: t) } }
guard let createList = sym("MTDeviceCreateList", (@convention(c) () -> Unmanaged<CFArray>?).self),
      let register = sym("MTRegisterContactFrameCallback", (@convention(c) (MTDeviceRef, Callback) -> Void).self),
      let start = sym("MTDeviceStart", (@convention(c) (MTDeviceRef, Int32) -> Void).self),
      let stop = sym("MTDeviceStop", (@convention(c) (MTDeviceRef) -> Void).self) else { print("functions missing"); exit(1) }

struct Contact { var id: Int32; var state: Int32; var x: Float; var y: Float }
let stride = 96

func say(_ s: String) {
    print("GESTURE: \(s)")
    let p = Process(); p.launchPath = "/usr/bin/say"; p.arguments = ["-r", "260", s]; try? p.run()
}

// A touch session: from the first finger down to the last finger up.
final class Session {
    var startTime = 0.0, endTime = 0.0
    var maxFingers = 0
    var start: [Int32: (Float, Float)] = [:]
    var last: [Int32: (Float, Float)] = [:]
    var startAngle: Float? = nil, lastAngle: Float? = nil
    var travel: Float = 0
}
nonisolated(unsafe) var session: Session? = nil
nonisolated(unsafe) var lastTapEnd = 0.0, lastTapFingers = 0, pendingTap: DispatchWorkItem? = nil
nonisolated(unsafe) var checked = false

func centroid(_ d: [Int32: (Float, Float)]) -> (Float, Float) {
    guard !d.isEmpty else { return (0, 0) }
    let s = d.values.reduce((Float(0), Float(0))) { ($0.0 + $1.0, $0.1 + $1.1) }
    return (s.0 / Float(d.count), s.1 / Float(d.count))
}
func angle(_ d: [Int32: (Float, Float)]) -> Float? {
    guard d.count == 2 else { return nil }
    let v = Array(d.values); return atan2(v[1].1 - v[0].1, v[1].0 - v[0].0) * 180 / .pi
}

func finish(_ s: Session) {
    let dur = s.endTime - s.startTime
    let a = centroid(s.start), b = centroid(s.last)
    let dx = b.0 - a.0, dy = b.1 - a.1
    let dist = (dx * dx + dy * dy).squareRoot()
    let n = s.maxFingers
    let fingers = n == 1 ? "one finger" : "\(n) fingers"
    if n == 2, let a0 = s.startAngle, let a1 = s.lastAngle {
        var turn = a1 - a0; if turn > 180 { turn -= 360 }; if turn < -180 { turn += 360 }
        if abs(turn) > 25 { say("rotate \(turn > 0 ? "anticlockwise" : "clockwise")"); return }
    }
    if dur < 0.3, dist < 0.04 {
        // A tap: a double tap if another of the same kind came just before.
        if s.startTime - lastTapEnd < 0.35, lastTapFingers == n {
            pendingTap?.cancel(); pendingTap = nil; lastTapEnd = 0
            say("double tap, \(fingers)")
        } else {
            lastTapEnd = s.endTime; lastTapFingers = n
            let w = DispatchWorkItem { say("tap, \(fingers)") }
            pendingTap = w
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.36, execute: w)
        }
        return
    }
    if dur < 0.45, dist > 0.12 {
        let dir = abs(dx) > abs(dy) ? (dx > 0 ? "right" : "left") : (dy > 0 ? "up" : "down")
        say("flick \(dir), \(fingers)")
        return
    }
    print(String(format: "other: %d fingers, %.2f s, moved %.2f (dx %.2f, dy %.2f)", n, dur, dist, dx, dy))
}

let cb: Callback = { _, data, n, ts, _ in
    var contacts: [Contact] = []
    if let data {
        for i in 0..<Int(n) {
            let p = data.advanced(by: i * stride)
            contacts.append(Contact(id: p.load(fromByteOffset: 16, as: Int32.self), state: p.load(fromByteOffset: 20, as: Int32.self),
                                    x: p.load(fromByteOffset: 32, as: Float.self), y: p.load(fromByteOffset: 36, as: Float.self)))
        }
    }
    if !checked, let c = contacts.first {
        checked = true
        print(String(format: "layout check: id %d, state %d, x %.3f, y %.3f (x and y should be between 0 and 1)", c.id, c.state, c.x, c.y))
    }
    let touching = contacts.filter { (3...5).contains($0.state) }   // make touch, touching, break touch
    let now = ts
    DispatchQueue.main.async {
        if !touching.isEmpty {
            let s = session ?? { let s = Session(); s.startTime = now; session = s; return s }()
            s.maxFingers = max(s.maxFingers, touching.count)
            for c in touching where s.start[c.id] == nil { s.start[c.id] = (c.x, c.y) }
            for c in touching { s.last[c.id] = (c.x, c.y) }
            if s.startAngle == nil, let a = angle(s.last) { s.startAngle = a }
            if let a = angle(s.last) { s.lastAngle = a }
            s.endTime = now
        } else if let s = session {
            session = nil
            finish(s)
        }
    }
    return 0
}

let devices = (createList()?.takeRetainedValue() as? [AnyObject]) ?? []
let refs = devices.map { Unmanaged.passUnretained($0).toOpaque() }
for d in refs { register(d, cb); start(d, 0) }
say("Trackpad gestures test. Try taps, double taps, flicks and a two finger turn. One minute.")
let end = Date().addingTimeInterval(60)
while Date() < end { RunLoop.main.run(until: Date().addingTimeInterval(0.5)) }
for d in refs { stop(d) }
let p = Process(); p.launchPath = "/usr/bin/say"; p.arguments = ["-r", "240", "Trackpad test done"]; try? p.run(); p.waitUntilExit()
