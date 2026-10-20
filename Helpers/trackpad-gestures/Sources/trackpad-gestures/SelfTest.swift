// SPDX-License-Identifier: GPL-3.0-or-later
// The recogniser checked with made-up touches: run with --self-test (TurnOver's build runs it).
import Foundation

enum SelfTest {
    static func run() -> Int32 {
        var failed = 0
        func expect(_ got: [Gesture], _ want: [Gesture], _ what: String) {
            if got != want { failed += 1; FileHandle.standardError.write(Data("\(what): got \(got), wanted \(want)\n".utf8)) }
        }
        func touch(_ r: Recogniser, _ path: [(Double, [Finger])], end: Double) -> [Gesture] {
            var g: [Gesture] = []
            for (t, f) in path { g += r.frame(f, at: t) }
            g += r.frame([], at: end)
            return g
        }
        let f = { (id: Int32, x: Float, y: Float) in Finger(id: id, x: x, y: y) }

        var r = Recogniser()
        var g = touch(r, [(0, [f(1, 0.5, 0.5)]), (0.1, [f(1, 0.501, 0.5)])], end: 0.12)
        g += r.flushTaps(at: 0.6)
        expect(g, [.tap(fingers: 1)], "one tap")

        r = Recogniser()
        g = touch(r, [(0, [f(1, 0.5, 0.5)])], end: 0.1)
        g += touch(r, [(0.25, [f(2, 0.5, 0.5)])], end: 0.33)
        g += r.flushTaps(at: 1)
        expect(g, [.doubleTap(fingers: 1)], "double tap")

        r = Recogniser()
        g = touch(r, [(0, [f(1, 0.3, 0.5)]), (0.1, [f(1, 0.4, 0.5)]), (0.2, [f(1, 0.55, 0.5)])], end: 0.22)
        expect(g, [.flick(direction: "right", fingers: 1)], "flick right")

        r = Recogniser()
        g = touch(r, [(0, [f(1, 0.4, 0.6), f(2, 0.6, 0.6)]), (0.1, [f(1, 0.4, 0.45), f(2, 0.6, 0.45)])], end: 0.15)
        expect(g, [.flick(direction: "down", fingers: 2)], "two-finger flick down")

        r = Recogniser()   // two fingers turning anticlockwise by about 70 degrees: two steps
        g = touch(r, [(0, [f(1, 0.4, 0.5), f(2, 0.6, 0.5)]), (0.2, [f(1, 0.43, 0.43), f(2, 0.57, 0.57)]), (0.4, [f(1, 0.47, 0.41), f(2, 0.53, 0.59)])], end: 0.5)
        expect(g, [.rotate(clockwise: false), .rotate(clockwise: false)], "turn anticlockwise")

        r = Recogniser()   // one finger resting, then moving: explore
        g = touch(r, [(0, [f(1, 0.2, 0.2)]), (0.3, [f(1, 0.2, 0.2)]), (0.5, [f(1, 0.3, 0.2)])], end: 0.8)
        expect(g, [.explore(x: 0.2, y: 0.2), .explore(x: 0.3, y: 0.2), .exploreEnd], "explore")

        r = Recogniser()   // two fingers back and forth: scrub
        var path: [(Double, [Finger])] = []
        for (i, x) in [0.40, 0.50, 0.40, 0.50, 0.40, 0.50].enumerated() { path.append((Double(i) * 0.1, [f(1, Float(x), 0.5), f(2, Float(x) + 0.1, 0.5)])) }
        g = touch(r, path, end: 0.7)
        expect(g, [.scrub], "scrub")

        print(failed == 0 ? "trackpad-gestures self-test: all passed" : "trackpad-gestures self-test: \(failed) failed")
        return failed == 0 ? 0 : 1
    }
}
