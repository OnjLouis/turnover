// SPDX-License-Identifier: GPL-3.0-or-later
// Gate 4, the real one: Caps Lock as a modifier, with VoiceOver off.
//
// The reader's method (an earlier open-source Mac screen reader's, and Vosh's): a non-seizing IOHIDManager reports
// the physical Caps Lock going down and up; an active session tap swallows
// the flagsChanged event the key generates so no app sees caps toggling; the
// HID system's caps lock state is put back after every press; a double tap
// turns real caps lock on or off. While Caps Lock is held, letter keys are
// swallowed and reported as chords. This probe SPEAKS with its own voice,
// because VoiceOver must be off for it (VoiceOver also owns Caps Lock).
//
// It waits for VoiceOver to be off, then: "Caps Lock down" / "up",
// "Caps Lock plus T", "caps lock on/off" on a double tap, and it logs the time
// from the HID timestamp to the start of speech. Escape ends it.
import Foundation
import IOKit
import IOKit.hid
import CoreGraphics
import Carbon.HIToolbox
import AVFoundation

nonisolated private final class Voice: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {   // the probe's run loop only
    let synth = AVSpeechSynthesizer()
    var pendingSince: UInt64 = 0
    var latenciesMs: [Double] = []
    override init() { super.init(); synth.delegate = self }
    func say(_ text: String, since: UInt64 = 0) {
        pendingSince = since
        synth.stopSpeaking(at: .immediate)
        let u = AVSpeechUtterance(string: text)
        u.voice = AVSpeechSynthesisVoice(identifier: "com.apple.eloquence.en-GB.Reed") ?? AVSpeechSynthesisVoice(language: "en-GB")
        u.rate = 0.55
        synth.speak(u)
    }
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        if pendingSince != 0 {
            let ms = Double(mach_absolute_time() &- pendingSince) * machToNs / 1_000_000
            latenciesMs.append(ms)
            pendingSince = 0
        }
    }
    func waitUntilDone() {
        while synth.isSpeaking { CFRunLoopRunInMode(.defaultMode, 0.05, true) }
    }
}

nonisolated private let machToNs: Double = {
    var info = mach_timebase_info(numer: 0, denom: 0)
    mach_timebase_info(&info)
    return Double(info.numer) / Double(info.denom)
}()

private let voice = Voice()
private var connect: io_connect_t = 0
private var capsDown = false
private var capsDownAt: UInt64 = 0
private var lastCapsUpAt: UInt64 = 0
private var chordFired = false
private var realCapsOn = false
private var finished = false
private var swallowedFlags = 0
private var swallowedKeys = 0
private var chords: [String] = []
private var quarantined = Set<Int64>()

private func setLock(_ on: Bool) {
    guard connect != 0 else { return }
    IOHIDSetModifierLockState(connect, Int32(kIOHIDCapsLockState), on)
}
private func lockIsOn() -> Bool {
    guard connect != 0 else { return false }
    var on = false
    IOHIDGetModifierLockState(connect, Int32(kIOHIDCapsLockState), &on)
    return on
}

private let hidValue: IOHIDValueCallback = { _, _, _, value in
    let element = IOHIDValueGetElement(value)
    guard IOHIDElementGetUsagePage(element) == UInt32(kHIDPage_KeyboardOrKeypad),
          IOHIDElementGetUsage(element) == UInt32(kHIDUsage_KeyboardCapsLock) else { return }
    let pressed = IOHIDValueGetIntegerValue(value) != 0
    let stamp = IOHIDValueGetTimeStamp(value)
    if pressed {
        capsDown = true; capsDownAt = stamp; chordFired = false
        Log.line("HID caps DOWN")
        // Put the lock state back to what the owner actually wants.
        setLock(realCapsOn)
        voice.say("down", since: stamp)
    } else {
        capsDown = false
        setLock(realCapsOn)
        let sinceLastUp = Double(stamp &- lastCapsUpAt) * machToNs / 1_000_000
        lastCapsUpAt = stamp
        if !chordFired && sinceLastUp < 350 {
            realCapsOn.toggle()
            setLock(realCapsOn)
            Log.line("HID caps UP — double tap: real caps lock \(realCapsOn ? "ON" : "off"); system reports \(lockIsOn() ? "ON" : "off")")
            voice.say(realCapsOn ? "caps lock on" : "caps lock off", since: stamp)
        } else if !chordFired {
            Log.line("HID caps UP — tap")
            voice.say("up", since: stamp)
        } else {
            Log.line("HID caps UP after chord")
        }
    }
}

private let activeTap: CGEventTapCallBack = { proxy, type, event, refcon in
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        Log.line("TAP disabled (\(type.rawValue)) — re-enabling")
        if let refcon { CGEvent.tapEnable(tap: Unmanaged<CFMachPort>.fromOpaque(refcon).takeUnretainedValue(), enable: true) }
        return Unmanaged.passUnretained(event)
    }
    let code = event.getIntegerValueField(.keyboardEventKeycode)
    if type == .flagsChanged && code == 57 {
        // The key's own event: never let an app see caps lock toggle.
        swallowedFlags += 1
        return nil
    }
    if type == .keyDown {
        if code == 53 && !capsDown { finished = true; return nil }   // Escape ends the test
        if capsDown {
            chordFired = true
            swallowedKeys += 1
            quarantined.insert(code)
            let name = keyName(event)
            chords.append(name)
            Log.line("chord: Caps Lock + \(name)")
            voice.say("caps \(name)", since: capsDownAt)
            return nil
        }
    }
    if type == .keyUp, quarantined.contains(code) {
        quarantined.remove(code)
        return nil
    }
    return Unmanaged.passUnretained(event)
}

private func keyName(_ event: CGEvent) -> String {
    var length = 0
    var chars = [UniChar](repeating: 0, count: 4)
    event.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &length, unicodeString: &chars)
    let s = String(utf16CodeUnits: chars, count: length).trimmingCharacters(in: .whitespacesAndNewlines)
    if s.isEmpty || s.unicodeScalars.contains(where: { $0.value < 32 }) { return "key \(event.getIntegerValueField(.keyboardEventKeycode))" }
    return s.uppercased()
}

func runCapsLockActiveGate(_ args: [String]) {
    let opts = Options(args)
    let maxSeconds = opts.double("seconds", 240)

    // Wait for VoiceOver to be off, reminding by voice.
    var reminded = Date.distantPast
    let waitEnd = Date().addingTimeInterval(180)
    while voiceOverRunning() && Date() < waitEnd {
        if Date().timeIntervalSince(reminded) > 15 {
            voice.say("TurnOver caps lock test. Turn VoiceOver off to begin.")
            reminded = Date()
        }
        CFRunLoopRunInMode(.defaultMode, 0.5, true)
    }
    guard !voiceOverRunning() else { Log.line("VoiceOver stayed on; not starting"); voice.say("VoiceOver is still on. Not starting."); voice.waitUntilDone(); return }
    Log.line("VoiceOver is off — starting")

    let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching(kIOHIDSystemClass))
    if service != 0 {
        let r = IOServiceOpen(service, mach_task_self_, UInt32(kIOHIDParamConnectType), &connect)
        IOObjectRelease(service)
        Log.line("IOHIDSystem connection: \(r == KERN_SUCCESS ? "open" : "failed \(r)"); caps lock currently \(lockIsOn() ? "ON" : "off")")
    }
    realCapsOn = lockIsOn()

    let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    IOHIDManagerSetDeviceMatchingMultiple(manager, [
        [kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop, kIOHIDDeviceUsageKey: kHIDUsage_GD_Keyboard],
        [kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop, kIOHIDDeviceUsageKey: kHIDUsage_GD_Keypad],
    ] as CFArray)
    IOHIDManagerRegisterInputValueCallback(manager, hidValue, nil)
    IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
    let openResult = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    Log.line("IOHIDManagerOpen: 0x\(String(UInt32(bitPattern: openResult), radix: 16)) (not-permitted with a device still delivering is the Karabiner case)")

    let mask = CGEventMask(1 << CGEventType.flagsChanged.rawValue | 1 << CGEventType.keyDown.rawValue | 1 << CGEventType.keyUp.rawValue)
    var tapRef: CFMachPort?
    guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                      eventsOfInterest: mask, callback: activeTap, userInfo: nil) else {
        Log.line("could not create an ACTIVE session tap"); voice.say("Could not create the event tap."); voice.waitUntilDone(); return
    }
    tapRef = tap
    CFRunLoopAddSource(CFRunLoopGetCurrent(), CFMachPortCreateRunLoopSource(nil, tap, 0), .defaultMode)
    Log.line("active session tap created")
    _ = tapRef

    voice.say("Ready. Press Caps Lock. Then hold Caps Lock and press T. Then double tap Caps Lock. Press Escape to finish.")
    let end = Date().addingTimeInterval(maxSeconds)
    while !finished && Date() < end { CFRunLoopRunInMode(.defaultMode, 0.05, true) }

    // Leave the system as we found it.
    setLock(false); realCapsOn = false
    CGEvent.tapEnable(tap: tap, enable: false)
    IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    Log.line("Summary: swallowed caps flagsChanged \(swallowedFlags), chord keys \(swallowedKeys) \(chords), caps lock state at end \(lockIsOn() ? "ON" : "off")")
    Log.line(summarize("HID press to speech start", voice.latenciesMs))
    voice.say("Finished. Turn VoiceOver back on.")
    voice.waitUntilDone()
    if connect != 0 { IOServiceClose(connect) }
}
