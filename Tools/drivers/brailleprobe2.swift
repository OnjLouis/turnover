// SPDX-License-Identifier: GPL-3.0-or-later
// Write a test line to a BAUM VarioUltra and print every report it sends (keys), for N seconds.
import Foundation
import IOKit.hid
setvbuf(stdout, nil, _IONBF, 0)
let seconds = Double(CommandLine.arguments.dropFirst().first ?? "60") ?? 60
let m = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
IOHIDManagerSetDeviceMatching(m, [kIOHIDVendorIDKey: 0x0904] as CFDictionary)
IOHIDManagerScheduleWithRunLoop(m, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
IOHIDManagerOpen(m, IOOptionBits(kIOHIDOptionsTypeNone))
guard let devs = IOHIDManagerCopyDevices(m) as? Set<IOHIDDevice>, let d = devs.first else { print("no display"); exit(1) }
let t0 = Date()
IOHIDDeviceRegisterInputReportCallback(d, UnsafeMutablePointer<UInt8>.allocate(capacity: 64), 64, { _, _, _, _, id, r, n in
    print(String(format: "%6.2f ", Date().timeIntervalSince(t0)) + "id \(id): " + (0..<n).map { String(format: "%02x", r[$0]) }.joined(separator: " "))
}, nil)
func send(_ b: [UInt8], _ label: String) {
    var r = b; if r.count < 21 { r += Array(repeating: 0, count: 21 - r.count) }
    let res = r.withUnsafeBufferPointer { IOHIDDeviceSetReport(d, kIOHIDReportTypeOutput, 0, $0.baseAddress!, $0.count) }
    print("sent \(label): \(String(format: "0x%x", res))")
}
// "TURNOVER TEST" in computer braille-ish dots (T=2345, U=136, R=1235, N=1345, O=135, V=1236, E=15, S=234), then dots 7-8 bar.
func cell(_ dots: String) -> UInt8 { dots.reduce(0) { $0 | (1 << (($1.wholeNumberValue ?? 1) - 1)) } }
let word = ["2345","136","1235","1345","135","1236","15","1235","","2345","15","234","2345","","78","78","78","78","78","78"].map(cell)
send([0x84], "identity request")
send([0x01] + word, "cells")
RunLoop.main.run(until: Date().addingTimeInterval(seconds))
send([0x01] + Array(repeating: 0, count: 20), "clear")
print("done")
