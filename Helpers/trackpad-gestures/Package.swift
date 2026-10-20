// swift-tools-version:5.9
// SPDX-License-Identifier: GPL-3.0-or-later
// Trackpad gestures' program: reads the fingers on a Mac trackpad, tells VoiceOver's gestures apart, plays haptics.
// Open, MIT. TurnOver builds it from this source, signs it with TurnOver and starts it without TurnOver's permissions.
import PackageDescription

let package = Package(
    name: "trackpad-gestures",
    platforms: [.macOS(.v14)],
    targets: [.executableTarget(name: "trackpad-gestures", path: "Sources/trackpad-gestures")]
)
