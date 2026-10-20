// SPDX-License-Identifier: GPL-3.0-or-later
// trackblock: step 4 of the trackpad work. While VoiceOver's Trackpad Commander is on, the trackpad drives VoiceOver
// only: no pointer, no clicks, no scrolling, no desktop switching. Can an event tap hold all of that back while the
// fingers are still read? For 40 s (dead-man) it drops pointer moves, clicks, scrolling and the trackpad's gesture
// events, counts what it dropped, and notes if the desktop changes anyway. The keyboard is never touched. When it
// ends, everything is as before (the tap goes with the process).
import AppKit
import CoreGraphics

func say(_ s: String) { let p = Process(); p.launchPath = "/usr/bin/say"; p.arguments = ["-r", "250", s]; try? p.run(); p.waitUntilExit() }

nonisolated(unsafe) var dropped: [String: Int] = [:]
let names: [UInt32: String] = [5: "pointer moved", 1: "click down", 2: "click up", 3: "right click down", 4: "right click up",
                               6: "drag", 22: "scroll", 29: "trackpad gesture", 30: "trackpad gesture (magnify, swipe)", 31: "trackpad gesture (other)"]
var mask: CGEventMask = 0
for t in names.keys { mask |= CGEventMask(1) << CGEventMask(t) }
let callback: CGEventTapCallBack = { _, type, event, _ in
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput { return Unmanaged.passUnretained(event) }
    let n = names[type.rawValue] ?? "type \(type.rawValue)"
    dropped[n, default: 0] += 1
    return nil
}
guard let tap = CGEvent.tapCreate(tap: .cghidEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: mask, callback: callback, userInfo: nil) else {
    print("could not create the tap (this program has no Accessibility permission)"); exit(1)
}
nonisolated(unsafe) var spaceChanges = 0
NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { _ in spaceChanges += 1 }
let start = CGEvent(source: nil)?.location ?? .zero
say("Trackpad block test. For 40 seconds, move the pointer, scroll, and try a three finger swipe. The keyboard still works.")
let src = CFMachPortCreateRunLoopSource(nil, tap, 0)
CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)
let end = Date().addingTimeInterval(40)
while Date() < end { RunLoop.main.run(until: Date().addingTimeInterval(0.5)) }
CGEvent.tapEnable(tap: tap, enable: false)
let finish = CGEvent(source: nil)?.location ?? .zero
print("held back: \(dropped.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }.joined(separator: ", "))")
print("pointer moved anyway: \(Int(abs(finish.x - start.x) + abs(finish.y - start.y))) points")
print("desktop switched anyway: \(spaceChanges) times")
say("Trackpad block test done. The trackpad works normally again.")
