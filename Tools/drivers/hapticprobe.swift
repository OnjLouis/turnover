// SPDX-License-Identifier: GPL-3.0-or-later
// hapticprobe: which trackpad haptics can a background program play? The public one (NSHapticFeedbackManager:
// generic, alignment, level change) and the private actuator (MultitouchSupport's MTActuator, the waveforms the
// Force Touch trackpad has built in). Says each one's name, then plays it three times. The finger must rest on the
// trackpad to feel anything. Read-only otherwise: nothing is clicked, the pointer keeps working.
import AppKit

func say(_ s: String) { let p = Process(); p.launchPath = "/usr/bin/say"; p.arguments = ["-r", "240", s]; try? p.run(); p.waitUntilExit() }

guard let h = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_NOW) else { print("no MultitouchSupport"); exit(1) }
func sym<T>(_ n: String, _ t: T.Type) -> T? { dlsym(h, n).map { unsafeBitCast($0, to: t) } }
typealias MTDeviceRef = UnsafeMutableRawPointer
let createList = sym("MTDeviceCreateList", (@convention(c) () -> Unmanaged<CFArray>?).self)
let getDeviceID = sym("MTDeviceGetDeviceID", (@convention(c) (MTDeviceRef, UnsafeMutablePointer<UInt64>) -> Int32).self)
let actuatorCreate = sym("MTActuatorCreateFromDeviceID", (@convention(c) (UInt64) -> Unmanaged<AnyObject>?).self)
let actuatorOpen = sym("MTActuatorOpen", (@convention(c) (AnyObject) -> Int32).self)
let actuatorClose = sym("MTActuatorClose", (@convention(c) (AnyObject) -> Int32).self)
let actuate = sym("MTActuatorActuate", (@convention(c) (AnyObject, Int32, UInt32, Float, Float) -> Int32).self)
print("private functions: list \(createList != nil), id \(getDeviceID != nil), create \(actuatorCreate != nil), open \(actuatorOpen != nil), actuate \(actuate != nil)")

say("Haptics test. Rest one finger on the trackpad, lightly, and keep it there. Each kind is named, then played three times.")

// The public ones.
let performer = NSHapticFeedbackManager.defaultPerformer
for (name, pattern) in [("generic", NSHapticFeedbackManager.FeedbackPattern.generic), ("alignment", .alignment), ("level change", .levelChange)] {
    say("Public, \(name)")
    for _ in 0..<3 { performer.perform(pattern, performanceTime: .now); Thread.sleep(forTimeInterval: 0.45) }
    print("public \(name): played")
}

// The private actuator, if it opens.
var actuator: AnyObject?
if let createList, let getDeviceID, let actuatorCreate, let actuatorOpen {
    let devices = (createList()?.takeRetainedValue() as? [AnyObject]) ?? []
    for d in devices {
        var id: UInt64 = 0
        _ = getDeviceID(Unmanaged.passUnretained(d).toOpaque(), &id)
        if let a = actuatorCreate(id)?.takeRetainedValue() {
            let r = actuatorOpen(a)
            print("actuator for device \(id): open \(r)")
            if r == 0 { actuator = a; break }
        }
    }
}
if let a = actuator, let actuate {
    for id: Int32 in [1, 2, 3, 4, 5, 6, 15, 16] {
        say("Private, number \(id)")
        var result: Int32 = 0
        for _ in 0..<3 { result = actuate(a, id, 0, 0, 0); Thread.sleep(forTimeInterval: 0.45) }
        print("private \(id): result \(result)")
    }
    _ = actuatorClose?(a)
} else {
    print("private actuator: not available")
    say("The private actuator isn't available.")
}
say("Haptics test done.")
