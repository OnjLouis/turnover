// SPDX-License-Identifier: GPL-3.0-or-later
// Gate 4, first half: can this process see the physical Caps Lock key?
//
// Both prior Mac screen readers (an earlier open-source Mac screen reader, and Vosh) use the same
// trick, and it is better than a remap: watch the Caps Lock scancode through a
// non-seizing IOHIDManager, and put the lock state back with
// IOHIDSetModifierLockState so the key never actually toggles. A crash leaves
// nothing behind. This probe only OBSERVES — it does not swallow the key and
// does not touch the lock state, because VoiceOver may be using Caps Lock as
// its own modifier while it runs. It reports:
//
//   - whether IOHIDManagerOpen succeeds without seizing (and so whether the
//     Accessibility grant alone is enough, or Input Monitoring is needed),
//   - every Caps Lock scancode, with the device it came from (with Karabiner
//     running, that should be its virtual keyboard, not the physical one),
//   - what a listen-only session event tap sees for the same presses
//     (flagsChanged with key code 57), and whether the alpha-shift flag moves,
//   - the HID system's lock state after each press,
//   - whether secure event input is on (it blinds the tap but maybe not HID).
import Foundation
import IOKit
import IOKit.hid
import CoreGraphics
import Carbon.HIToolbox

private var hidCapsCount = 0
private var hidOtherCount = 0
private var tapCapsCount = 0
private var tapOtherCount = 0
private var hidConnect: io_connect_t = 0

private func lockState() -> String {
    guard hidConnect != 0 else { return "n/a" }
    var on = false
    let r = IOHIDGetModifierLockState(hidConnect, Int32(kIOHIDCapsLockState), &on)
    return r == KERN_SUCCESS ? (on ? "ON" : "off") : "err \(r)"
}

private func deviceName(_ sender: UnsafeMutableRawPointer?) -> String {
    guard let sender else { return "?" }
    let device = Unmanaged<IOHIDDevice>.fromOpaque(sender).takeUnretainedValue()
    let product = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String ?? "?"
    let transport = IOHIDDeviceGetProperty(device, kIOHIDTransportKey as CFString) as? String ?? "?"
    return "\(product) [\(transport)]"
}

private let hidCallback: IOHIDValueCallback = { _, _, sender, value in
    let element = IOHIDValueGetElement(value)
    let page = IOHIDElementGetUsagePage(element)
    let usage = IOHIDElementGetUsage(element)
    let pressed = IOHIDValueGetIntegerValue(value) != 0
    guard page == UInt32(kHIDPage_KeyboardOrKeypad) else { return }
    if usage == UInt32(kHIDUsage_KeyboardCapsLock) {
        hidCapsCount += 1
        Log.line("HID  caps lock \(pressed ? "DOWN" : "up  ") from \(deviceName(sender)); lock state now \(lockState())")
    } else if pressed {
        hidOtherCount += 1
        if hidOtherCount <= 3 { Log.line("HID  some other key down (usage 0x\(String(usage, radix: 16))) from \(deviceName(sender))") }
    }
}

private let tapCallback: CGEventTapCallBack = { proxy, type, event, refcon in
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        Log.line("TAP  disabled (\(type.rawValue)) — re-enabling")
        if let refcon { CGEvent.tapEnable(tap: Unmanaged<CFMachPort>.fromOpaque(refcon).takeUnretainedValue(), enable: true) }
        return Unmanaged.passUnretained(event)
    }
    let code = event.getIntegerValueField(.keyboardEventKeycode)
    if type == .flagsChanged {
        if code == 57 {
            tapCapsCount += 1
            let alpha = event.flags.contains(.maskAlphaShift)
            Log.line("TAP  flagsChanged key 57 (caps lock), alphaShift flag \(alpha ? "SET" : "clear"), secure input \(IsSecureEventInputEnabled() ? "ON" : "off")")
        }
    } else if type == .keyDown {
        tapOtherCount += 1
        if tapOtherCount <= 3 { Log.line("TAP  keyDown code \(code) (contents not logged)") }
    }
    return Unmanaged.passUnretained(event)
}

func runCapsLockGate(_ args: [String]) {
    let opts = Options(args)
    let seconds = opts.double("seconds", 30)

    Log.line("Secure event input at start: \(IsSecureEventInputEnabled() ? "ON" : "off")")
    Log.line("Please press Caps Lock three or four times, then one letter key, within \(Int(seconds)) seconds.")

    // The HID system connection, for reading the lock state (not writing it).
    let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching(kIOHIDSystemClass))
    if service != 0 {
        let r = IOServiceOpen(service, mach_task_self_, UInt32(kIOHIDParamConnectType), &hidConnect)
        IOObjectRelease(service)
        Log.line("IOHIDSystem param connection: \(r == KERN_SUCCESS ? "open" : "failed \(r)"); lock state \(lockState())")
    } else {
        Log.line("IOHIDSystem service not found")
    }

    // Non-seizing HID manager over every keyboard and keypad.
    let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    let matches: [[String: Int]] = [
        [kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop, kIOHIDDeviceUsageKey: kHIDUsage_GD_Keyboard],
        [kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop, kIOHIDDeviceUsageKey: kHIDUsage_GD_Keypad],
    ]
    IOHIDManagerSetDeviceMatchingMultiple(manager, matches as CFArray)
    IOHIDManagerRegisterInputValueCallback(manager, hidCallback, nil)
    IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
    let openResult = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    Log.line("IOHIDManagerOpen (non-seizing): \(openResult == kIOReturnSuccess ? "success" : "failed 0x\(String(UInt32(bitPattern: openResult), radix: 16))")")
    if let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> {
        for d in devices {
            let product = IOHIDDeviceGetProperty(d, kIOHIDProductKey as CFString) as? String ?? "?"
            let transport = IOHIDDeviceGetProperty(d, kIOHIDTransportKey as CFString) as? String ?? "?"
            Log.line("HID  keyboard device: \(product) [\(transport)]")
        }
    } else {
        Log.line("HID  no keyboard devices matched (a permission problem if Input Monitoring is needed)")
    }

    // Listen-only session tap. Runs on this same run loop for the probe; the
    // reader gives the tap its own thread.
    let mask = CGEventMask(1 << CGEventType.flagsChanged.rawValue | 1 << CGEventType.keyDown.rawValue)
    var tapRef: CFMachPort?
    if let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                   options: .listenOnly, eventsOfInterest: mask,
                                   callback: tapCallback, userInfo: nil) {
        tapRef = tap
        CFRunLoopAddSource(CFRunLoopGetCurrent(), CFMachPortCreateRunLoopSource(nil, tap, 0), .defaultMode)
        Log.line("TAP  listen-only session tap created")
    } else {
        Log.line("TAP  could not create a session tap (Accessibility or Input Monitoring not granted to this process)")
    }
    _ = tapRef

    CFRunLoopRunInMode(.defaultMode, seconds, false)

    Log.line("Summary: HID caps lock events \(hidCapsCount), HID other key-downs \(hidOtherCount), tap caps lock flagsChanged \(tapCapsCount), tap other keyDowns \(tapOtherCount)")
    Log.line("Lock state at end: \(lockState()); secure event input: \(IsSecureEventInputEnabled() ? "ON" : "off")")
    if hidCapsCount == 0 && tapCapsCount == 0 {
        Log.line("Verdict: nothing arrived. Either Caps Lock was not pressed, or neither route can see it from this process.")
    } else if hidCapsCount > 0 {
        Log.line("Verdict: the HID route sees Caps Lock, which is what the reader needs for the modifier.")
    } else {
        Log.line("Verdict: only the tap sees Caps Lock; the HID route needs Input Monitoring or is blocked.")
    }
    IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    if hidConnect != 0 { IOServiceClose(hidConnect) }
}
