// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
import IOKit.hid
import TurnOverCore

/// Input Monitoring, which TurnOver needs to watch the keyboard itself (Caps Lock as the TurnOver key).
///
/// IOHIDCheckAccess can go on answering "not granted" in a running TurnOver after the user has turned it on in
/// System Settings: a tester granted it, TurnOver kept asking, and only removing and re-adding TurnOver (and a
/// restart) cleared it (5 Oct 2026). Opening the keyboards is the real test: macOS checks the permission then.
enum InputAccess {
    private static var lastLogged: Bool?

    static var granted: Bool {
        var ok = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
        if !ok {
            let m = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
            IOHIDManagerSetDeviceMatching(m, [kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop, kIOHIDDeviceUsageKey: kHIDUsage_GD_Keyboard] as CFDictionary)
            ok = IOHIDManagerOpen(m, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess
            IOHIDManagerClose(m, IOOptionBits(kIOHIDOptionsTypeNone))
            if ok { Log.info("Input Monitoring: granted (IOHIDCheckAccess still says not; the keyboards opened)") }
        }
        if lastLogged != ok { lastLogged = ok; Log.info("Input Monitoring: \(ok ? "granted" : "not granted")") }
        return ok
    }

    /// Ask at most once each time TurnOver runs: asking again (and opening System Settings again) on every take-over
    /// was the request that kept coming back.
    private static var asked = false
    static func askOnce() -> Bool {
        guard !asked else { return false }
        asked = true
        _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        return true
    }
}
