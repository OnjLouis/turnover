// SPDX-License-Identifier: GPL-3.0-or-later
// displayawake: exit 0 when the main display is awake and the session unlocked, so keys sent and apps opened can reach
// the screen; 1 otherwise (asleep, a dark wake with the lid shut, or locked). Read-only. (13 Oct 2026: an unattended
// regression pass ran in dark wakes, and every app it opened stayed behind Claude.)
import Foundation
import CoreGraphics
let asleep = CGDisplayIsAsleep(CGMainDisplayID()) != 0
let session = CGSessionCopyCurrentDictionary() as? [String: Any] ?? [:]
let locked = (session["CGSSessionScreenIsLocked"] as? Bool) ?? false
let onConsole = (session[kCGSessionOnConsoleKey as String] as? Bool) ?? true
print(asleep ? "display asleep" : locked ? "screen locked" : !onConsole ? "not on console" : "awake")
exit(asleep || locked || !onConsole ? 1 : 0)
