// SPDX-License-Identifier: GPL-3.0-or-later
// trackprobe: can TurnOver read fingers on the trackpad (Apple's private MultitouchSupport)? Read-only: it only
// listens, the pointer keeps working, nothing is clicked or pressed. Ends by itself after 20 s (dead-man), says
// "touch the trackpad now" and "trackpad test done" with the Mac's say command, and prints finger counts only.
import Foundation
typealias MTDeviceRef = UnsafeMutableRawPointer
typealias Callback = @convention(c) (MTDeviceRef?, UnsafeMutableRawPointer?, Int32, Double, Int32) -> Int32
guard let h = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_NOW) else { print("no MultitouchSupport"); exit(1) }
func sym<T>(_ n: String, _ t: T.Type) -> T? { dlsym(h, n).map { unsafeBitCast($0, to: t) } }
guard let createList = sym("MTDeviceCreateList", (@convention(c) () -> Unmanaged<CFArray>?).self),
      let register = sym("MTRegisterContactFrameCallback", (@convention(c) (MTDeviceRef, Callback) -> Void).self),
      let start = sym("MTDeviceStart", (@convention(c) (MTDeviceRef, Int32) -> Void).self),
      let stop = sym("MTDeviceStop", (@convention(c) (MTDeviceRef) -> Void).self) else { print("functions missing"); exit(1) }
let devices = (createList()?.takeRetainedValue() as? [AnyObject]) ?? []
print("trackpads and touch devices found: \(devices.count)")
if CommandLine.arguments.contains("--list") { exit(0) }
nonisolated(unsafe) var frames = 0, maxFingers = 0
nonisolated(unsafe) var counts: [Int: Int] = [:]
let cb: Callback = { _, _, n, _, _ in
    frames += 1; maxFingers = max(maxFingers, Int(n)); counts[Int(n), default: 0] += 1; return 0
}
let refs = devices.map { Unmanaged.passUnretained($0).toOpaque() }
for d in refs { register(d, cb); start(d, 0) }
Process.launchedProcess(launchPath: "/usr/bin/say", arguments: ["-r", "220", "Touch the trackpad now, with one, two and three fingers"])
let end = Date().addingTimeInterval(20)
while Date() < end {
    RunLoop.current.run(until: Date().addingTimeInterval(2))
    print(String(format: "%2.0f s: %d frames, most fingers %d", 20 - end.timeIntervalSinceNow, frames, maxFingers))
}
for d in refs { stop(d) }
print("finger counts seen: \(counts.sorted { $0.key < $1.key }.map { "\($0.key) fingers: \($0.value) frames" }.joined(separator: ", "))")
Process.launchedProcess(launchPath: "/usr/bin/say", arguments: ["-r", "220", "Trackpad test done"]).waitUntilExit()
