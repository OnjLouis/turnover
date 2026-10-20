// SPDX-License-Identifier: GPL-3.0-or-later
// quitnamed: asks apps to quit the ordinary way (NSRunningApplication.terminate, as the Dock's Quit does), by name,
// for the regression runner's clean-up. quitapp only closed the windows of sixteen apps on 19 Oct 2026, and they were
// left running. Prints each app and whether it went within five seconds.
import AppKit
let names = Array(CommandLine.arguments.dropFirst())
for name in names {
    let apps = NSWorkspace.shared.runningApplications.filter { $0.localizedName?.trimmingCharacters(in: CharacterSet(charactersIn: "\u{200E}\u{200F}")) == name }
    for a in apps { _ = a.terminate() }
}
let until = Date().addingTimeInterval(5)
while Date() < until, names.contains(where: { n in NSWorkspace.shared.runningApplications.contains { $0.localizedName?.trimmingCharacters(in: CharacterSet(charactersIn: "\u{200E}\u{200F}")) == n } }) {
    RunLoop.current.run(until: Date().addingTimeInterval(0.25))
}
for n in names {
    let left = NSWorkspace.shared.runningApplications.contains { $0.localizedName?.trimmingCharacters(in: CharacterSet(charactersIn: "\u{200E}\u{200F}")) == n }
    print("\(n): \(left ? "still running" : "quit")")
}
