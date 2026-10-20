// SPDX-License-Identifier: GPL-3.0-or-later
// quitapp <bundle id>: asks the app to quit as the Dock does (no Apple events, so no automation prompt), then
// waits up to 5 s; prints "closed" or "still running".
import AppKit
let id = CommandLine.arguments[1]
for a in NSRunningApplication.runningApplications(withBundleIdentifier: id) { a.terminate() }
for _ in 0..<50 { if NSRunningApplication.runningApplications(withBundleIdentifier: id).isEmpty { print("\(id): closed"); exit(0) }; usleep(100_000) }
print("\(id): still running"); exit(1)
