// SPDX-License-Identifier: GPL-3.0-or-later
// The trackpad's haptics. The private actuator (MTActuator, MultitouchSupport) plays the Force Touch trackpad's
// built-in waveforms from any program; the public NSHapticFeedbackManager is the fallback. Either is felt only with
// a finger on the trackpad, which is where it is during trackpad control.
import AppKit

final class Haptics {
    private var actuator: AnyObject?
    private var actuate: (@convention(c) (AnyObject, Int32, UInt32, Float, Float) -> Int32)?
    /// The waveforms all feel much alike (14 Oct 2026), so the kinds differ by rhythm: a tick is one tap
    /// (a step, an item), a double two quick taps (something notable: a heading), a bump three (an edge).
    let pulses: [String: Int] = ["tick": 1, "light": 1, "double": 2, "bump": 3]
    let waveform: Int32 = 6

    func open() {
        guard let h = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_NOW) else { return }
        func sym<T>(_ n: String, _ t: T.Type) -> T? { dlsym(h, n).map { unsafeBitCast($0, to: t) } }
        guard let list = sym("MTDeviceCreateList", (@convention(c) () -> Unmanaged<CFArray>?).self),
              let getID = sym("MTDeviceGetDeviceID", (@convention(c) (UnsafeMutableRawPointer, UnsafeMutablePointer<UInt64>) -> Int32).self),
              let create = sym("MTActuatorCreateFromDeviceID", (@convention(c) (UInt64) -> Unmanaged<AnyObject>?).self),
              let openA = sym("MTActuatorOpen", (@convention(c) (AnyObject) -> Int32).self) else { out("L haptics: the private actuator is missing; the public haptics only"); return }
        actuate = sym("MTActuatorActuate", (@convention(c) (AnyObject, Int32, UInt32, Float, Float) -> Int32).self)
        for d in (list()?.takeRetainedValue() as? [AnyObject]) ?? [] {
            var id: UInt64 = 0
            _ = getID(Unmanaged.passUnretained(d).toOpaque(), &id)
            if let a = create(id)?.takeRetainedValue(), openA(a) == 0 { actuator = a; break }
        }
        out("L haptics: \(actuator != nil ? "the trackpad's own waveforms" : "the public haptics only")")
    }

    func play(_ kind: String) {
        let n = pulses[kind] ?? 1
        for i in 0..<n {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.09) { [self] in
                if let a = actuator, let actuate { _ = actuate(a, waveform, 0, 0, 0) }
                else { NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now) }
            }
        }
    }
}
