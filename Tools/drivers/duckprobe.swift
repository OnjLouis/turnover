// SPDX-License-Identifier: GPL-3.0-or-later
// duckprobe: can a third-party app duck other apps' sound while it speaks? (NVDA's audio ducking, NVDA+Shift+D;
// 12 Oct 2026: "look into ducking as it isn't confirmed".)
//
// Core Audio process taps (macOS 14.2+): tap every process but this one, muted while tapped, and play the tapped
// sound back through the output at a gain we choose. For 12 seconds the gain alternates: 2 s full, 2 s at 30 %.
// macOS asks once for permission to record other apps' audio: run this only with someone there to answer it.
//
// Build: swiftc -O duckprobe.swift -o duckprobe     Run: ./duckprobe   (play some music first)
import Foundation
import CoreAudio
import AudioToolbox

// A dead-man switch: whatever happens, after 20 s the process exits, and with it the tap and the aggregate device.
DispatchQueue.global().asyncAfter(deadline: .now() + 20) { print("dead-man switch: exiting"); exit(2) }
signal(SIGINT) { _ in exit(130) }

func check(_ s: OSStatus, _ what: String) { if s != noErr { print("\(what) failed: \(s)"); exit(1) } }

func defaultOutputUID() -> String {
    var dev = AudioObjectID(0); var size = UInt32(MemoryLayout<AudioObjectID>.size)
    var a = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    check(AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &a, 0, nil, &size, &dev), "default output")
    var uid: Unmanaged<CFString>?; size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
    a.mSelector = kAudioDevicePropertyDeviceUID
    check(AudioObjectGetPropertyData(dev, &a, 0, nil, &size, &uid), "output UID")
    return uid!.takeRetainedValue() as String
}

func ownProcessObject() -> AudioObjectID? {
    var pid = getpid(); var obj = AudioObjectID(0); var size = UInt32(MemoryLayout<AudioObjectID>.size)
    var a = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyTranslatePIDToProcessObject, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    let s = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &a, UInt32(MemoryLayout<pid_t>.size), &pid, &size, &obj)
    return s == noErr && obj != 0 ? obj : nil
}

let outputUID = defaultOutputUID()
let tapDesc = CATapDescription(stereoGlobalTapButExcludeProcesses: ownProcessObject().map { [$0] } ?? [])
tapDesc.name = "TurnOver duck probe"
// Unmuted until our own playback is running (12 Oct 2026: muted first, the probe stuck before playing, and every
// app on the maintainer's Mac went silent, the screen reader included).
tapDesc.muteBehavior = .unmuted
tapDesc.isPrivate = true
var tapID = AudioObjectID(0)
check(AudioHardwareCreateProcessTap(tapDesc, &tapID), "create tap (permission refused?)")
print("tap \(tapID)")

let aggUID = UUID().uuidString
let desc: [String: Any] = [
    kAudioAggregateDeviceNameKey: "TurnOver duck probe",
    kAudioAggregateDeviceUIDKey: aggUID,
    kAudioAggregateDeviceMainSubDeviceKey: outputUID,
    kAudioAggregateDeviceIsPrivateKey: true,
    kAudioAggregateDeviceIsStackedKey: false,
    kAudioAggregateDeviceTapAutoStartKey: true,
    kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outputUID]],
    kAudioAggregateDeviceTapListKey: [[kAudioSubTapDriftCompensationKey: true, kAudioSubTapUIDKey: tapDesc.uuid.uuidString]],
]
var aggID = AudioObjectID(0)
check(AudioHardwareCreateAggregateDevice(desc as CFDictionary, &aggID), "create aggregate device")
print("aggregate \(aggID)")

final class Gain: @unchecked Sendable { var value: Float = 1 }
let gain = Gain()
var procID: AudioDeviceIOProcID?
check(AudioDeviceCreateIOProcIDWithBlock(&procID, aggID, nil) { _, input, _, output, _ in
    let ins = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
    let outs = UnsafeMutableAudioBufferListPointer(output)
    for (i, o) in outs.enumerated() {
        guard let od = o.mData else { continue }
        let n = Int(o.mDataByteSize) / MemoryLayout<Float>.size
        let op = od.assumingMemoryBound(to: Float.self)
        if i < ins.count, let id = ins[i].mData {
            let ip = id.assumingMemoryBound(to: Float.self)
            let m = min(n, Int(ins[i].mDataByteSize) / MemoryLayout<Float>.size)
            for k in 0..<m { op[k] = ip[k] * gain.value }
            if m < n { for k in m..<n { op[k] = 0 } }
        } else { for k in 0..<n { op[k] = 0 } }
    }
}, "IO proc")
check(AudioDeviceStart(aggID, procID), "start")
// Only now, with our playback running, may the tapped apps be muted (and replayed by us).
var muted = CATapMuteBehavior.mutedWhenTapped
var addr = AudioObjectPropertyAddress(mSelector: kAudioTapPropertyDescription, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
tapDesc.muteBehavior = muted
var descRef: CATapDescription = tapDesc
let setStatus = withUnsafePointer(to: &descRef) { AudioObjectSetPropertyData(tapID, &addr, 0, nil, UInt32(MemoryLayout<CATapDescription>.size), $0) }
print("mute while tapped: \(setStatus == noErr ? "on" : "could not be set (\(setStatus)): playback doubles instead of ducking")")
_ = muted
print("running: full, then 30 %, every 2 s, for 12 s")
for step in 0..<6 {
    gain.value = step % 2 == 0 ? 1 : 0.3
    print(gain.value == 1 ? "full" : "ducked")
    Thread.sleep(forTimeInterval: 2)
}
AudioDeviceStop(aggID, procID)
if let p = procID { AudioDeviceDestroyIOProcID(aggID, p) }
AudioHardwareDestroyAggregateDevice(aggID)
AudioHardwareDestroyProcessTap(tapID)
print("stopped; tap and aggregate device removed")
