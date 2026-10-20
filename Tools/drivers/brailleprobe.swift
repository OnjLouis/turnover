// SPDX-License-Identifier: GPL-3.0-or-later
// Braille display probe (docs/BRAILLE-PLAN.md step 1): lists BAUM HID devices (vendor 0x0904) and any device on the HID
// braille usage page (0x41), opens them without seizing, and prints every input report in hex for 30 s.
import Foundation
import IOKit.hid
setvbuf(stdout, nil, _IONBF, 0)
let m = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
IOHIDManagerSetDeviceMatchingMultiple(m, [[kIOHIDVendorIDKey: 0x0904], [kIOHIDPrimaryUsagePageKey: 0x41]] as CFArray)
func prop(_ d: IOHIDDevice, _ k: String) -> Any? { IOHIDDeviceGetProperty(d, k as CFString) }
IOHIDManagerRegisterDeviceMatchingCallback(m, { _, r, _, d in
    print("device: \(prop(d, kIOHIDProductKey) ?? "?") vendor \(String(format: "0x%04x", prop(d, kIOHIDVendorIDKey) as? Int ?? 0)) product \(String(format: "0x%04x", prop(d, kIOHIDProductIDKey) as? Int ?? 0)) usage page \(String(format: "0x%x", prop(d, kIOHIDPrimaryUsagePageKey) as? Int ?? 0)) transport \(prop(d, kIOHIDTransportKey) ?? "?") in \(prop(d, kIOHIDMaxInputReportSizeKey) ?? "?") out \(prop(d, kIOHIDMaxOutputReportSizeKey) ?? "?") open \(String(format: "0x%x", r))")
}, nil)
IOHIDManagerRegisterInputReportCallback(m, { _, _, _, _, id, report, len in
    print("report \(id): " + (0..<len).map { String(format: "%02x", report[$0]) }.joined(separator: " "))
}, nil)
IOHIDManagerScheduleWithRunLoop(m, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
print("open: \(String(format: "0x%x", IOHIDManagerOpen(m, IOOptionBits(kIOHIDOptionsTypeNone))))")
RunLoop.main.run(until: Date().addingTimeInterval(Double(CommandLine.arguments.dropFirst().first ?? "30") ?? 30))
print("done")
