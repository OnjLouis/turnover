// SPDX-License-Identifier: GPL-3.0-or-later
// Telling gestures apart, from finger positions alone. Pure: frames in, gestures out, so it can be tested.
//
// Positions are the trackpad's own, 0 to 1 across and 0 to 1 from bottom to top. Times are seconds.
import Foundation

public struct Finger: Equatable {
    public var id: Int32
    public var x: Float, y: Float
    public init(id: Int32, x: Float, y: Float) { self.id = id; self.x = x; self.y = y }
}

public enum Gesture: Equatable {
    case tap(fingers: Int), doubleTap(fingers: Int), tripleTap(fingers: Int)
    case flick(direction: String, fingers: Int)          // "left", "right", "up", "down"
    case rotate(clockwise: Bool)                         // one step of a two-finger turn (30 degrees)
    case scrub                                           // two fingers back and forth: VoiceOver's Escape
    case explore(x: Float, y: Float), exploreEnd         // one finger resting and moving

    /// The line sent to TurnOver.
    public var line: String {
        switch self {
        case .tap(let n): return "G tap \(n)"
        case .doubleTap(let n): return "G double-tap \(n)"
        case .tripleTap(let n): return "G triple-tap \(n)"
        case .flick(let d, let n): return "G flick-\(d) \(n)"
        case .rotate(let cw): return "R \(cw ? "cw" : "ccw")"
        case .scrub: return "G scrub"
        case .explore(let x, let y): return String(format: "E %.3f %.3f", x, y)
        case .exploreEnd: return "E end"
        }
    }
}

public final class Recogniser {
    // Thresholds, measured by hand on 14 Oct 2026 (trackprobe2).
    // Flicks shorter and quicker, nearer VoiceOver's own feel (17 Oct 2026: "less sensitive than VoiceOver").
    let tapTime = 0.30, tapMove: Float = 0.04, multiTapGap = 0.35
    let flickTime = 0.55, flickMove: Float = 0.06
    let rotateStep: Float = 30, exploreAfter = 0.22, exploreStep: Float = 0.008
    let scrubTurns = 3, scrubAmplitude: Float = 0.04

    private var start: [Int32: (Float, Float)] = [:]
    private var last: [Int32: (Float, Float)] = [:]
    private var startTime = 0.0, lastTime = 0.0
    private var maxFingers = 0
    private var angleBase: Float?
    private var rotated = false
    private var exploring = false
    private var lastExplore: (Float, Float)?
    // Scrub: the centroid's horizontal turns.
    private var scrubDir = 0, scrubTurnsSeen = 0, scrubExtreme: Float = 0
    // Taps waiting to see if another follows.
    private var pendingTaps = 0, pendingFingers = 0, pendingSince = 0.0
    /// Where the last tap was (the fingers' centre, 0 to 1 across and from the bottom): VoiceOver's two-finger
    /// double-taps mean different things near the top, bottom, left and right of the trackpad.
    public private(set) var lastTapAt: (Float, Float) = (0.5, 0.5)

    public init() {}

    private func centroid(_ d: [Int32: (Float, Float)]) -> (Float, Float) {
        guard !d.isEmpty else { return (0, 0) }
        let s = d.values.reduce((Float(0), Float(0))) { ($0.0 + $1.0, $0.1 + $1.1) }
        return (s.0 / Float(d.count), s.1 / Float(d.count))
    }
    private func angle(_ d: [Int32: (Float, Float)]) -> Float? {
        guard d.count == 2 else { return nil }
        let v = d.sorted { $0.key < $1.key }.map(\.value)
        return atan2(v[1].1 - v[0].1, v[1].0 - v[0].0) * 180 / .pi
    }

    /// One frame: the fingers touching now (empty when all are lifted). Returns what it recognised.
    public func frame(_ fingers: [Finger], at t: Double) -> [Gesture] {
        var out: [Gesture] = []
        if fingers.isEmpty {
            if !last.isEmpty { out += finish(at: t) }
            return out + flushTaps(at: t)
        }
        if last.isEmpty {   // a new touch
            startTime = t; maxFingers = 0; rotated = false; exploring = false; lastExplore = nil
            angleBase = nil; scrubDir = 0; scrubTurnsSeen = 0; scrubExtreme = 0; start = [:]
        }
        let now = Dictionary(uniqueKeysWithValues: fingers.map { ($0.id, ($0.x, $0.y)) })
        for (id, p) in now where start[id] == nil { start[id] = p }
        last = now; lastTime = t
        maxFingers = max(maxFingers, fingers.count)

        // A two-finger turn: a step each 30 degrees, while it turns (a dial's detents).
        if fingers.count == 2, let a = angle(now) {
            if let base = angleBase {
                var turn = a - base
                if turn > 180 { turn -= 360 }; if turn < -180 { turn += 360 }
                // Detents every 30 degrees from where the turn began, however fast the frames come.
                var detent = base
                while abs(turn) >= rotateStep {
                    out.append(.rotate(clockwise: turn < 0)); rotated = true
                    detent += turn > 0 ? rotateStep : -rotateStep
                    turn += turn > 0 ? -rotateStep : rotateStep
                }
                angleBase = detent
            } else { angleBase = a }
        }
        // A two-finger scrub: the centroid turning back and forth sideways.
        if fingers.count == 2 {
            let cx = centroid(now).0
            if scrubDir == 0 { scrubExtreme = cx; scrubDir = 2 }
            else if scrubDir == 2 { if abs(cx - scrubExtreme) > scrubAmplitude { scrubDir = cx > scrubExtreme ? 1 : -1; scrubExtreme = cx } }
            else if scrubDir == 1 { if cx > scrubExtreme { scrubExtreme = cx } else if scrubExtreme - cx > scrubAmplitude { scrubDir = -1; scrubTurnsSeen += 1; scrubExtreme = cx } }
            else if scrubDir == -1 { if cx < scrubExtreme { scrubExtreme = cx } else if cx - scrubExtreme > scrubAmplitude { scrubDir = 1; scrubTurnsSeen += 1; scrubExtreme = cx } }
        }
        // One finger resting a moment, then moving or not: exploring by touch.
        if maxFingers == 1, fingers.count == 1, t - startTime >= exploreAfter {
            let p = now.values.first!
            let s = start.values.first!
            // Once exploring, a move is exploring, however quick (with shorter flicks a rest-then-move read as a flick).
            let quick = !exploring && hypot(p.0 - s.0, p.1 - s.1) > flickMove && t - startTime < flickTime
            if !quick {
                if !exploring { exploring = true; out += flushTaps(at: t) }
                if lastExplore.map({ hypot(p.0 - $0.0, p.1 - $0.1) >= exploreStep }) ?? true {
                    lastExplore = p
                    out.append(.explore(x: p.0, y: p.1))
                }
            }
        }
        return out
    }

    private func finish(at t: Double) -> [Gesture] {
        defer { last = [:] }
        if exploring { return [.exploreEnd] }
        if rotated { return [] }
        if maxFingers == 2, scrubTurnsSeen >= scrubTurns, lastTime - startTime < 2 { return [.scrub] }
        let duration = lastTime - startTime
        let a = centroid(start.filter { last[$0.key] != nil }.isEmpty ? start : start.filter { last[$0.key] != nil })
        let b = centroid(last)
        let dx = b.0 - a.0, dy = b.1 - a.1
        let dist = hypot(dx, dy)
        if duration < tapTime, dist < tapMove {
            lastTapAt = b
            if pendingTaps > 0, pendingFingers == maxFingers, startTime - pendingSince < multiTapGap {
                pendingTaps += 1
            } else {
                let flushed = flushTaps(at: .infinity)
                pendingTaps = 1; pendingFingers = maxFingers
                pendingSince = t
                if pendingTaps >= 3 { return flushed + flushTaps(at: .infinity) }
                return flushed
            }
            pendingSince = t
            if pendingTaps >= 3 { return flushTaps(at: .infinity) }
            return []
        }
        if duration < flickTime, dist > flickMove {
            let dir = abs(dx) > abs(dy) ? (dx > 0 ? "right" : "left") : (dy > 0 ? "up" : "down")
            return flushTaps(at: .infinity) + [.flick(direction: dir, fingers: maxFingers)]
        }
        return []
    }

    /// Taps waiting for a second or third: given out once no other can come (or at once, with `.infinity`).
    public func flushTaps(at t: Double) -> [Gesture] {
        guard pendingTaps > 0, t - pendingSince >= multiTapGap else { return [] }
        defer { pendingTaps = 0 }
        switch pendingTaps {
        case 1: return [.tap(fingers: pendingFingers)]
        case 2: return [.doubleTap(fingers: pendingFingers)]
        default: return [.tripleTap(fingers: pendingFingers)]
        }
    }
}
