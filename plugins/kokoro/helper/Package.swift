// swift-tools-version: 6.0
// SPDX-License-Identifier: GPL-3.0-or-later
// The Kokoro voice helper: natural voices made on the Mac, for TurnOver's external-voice path. Its own program, so a
// crash in the voice engine never takes TurnOver down. FluidAudio (Apache 2.0), Core ML, no Python, no GPL parts.
import PackageDescription
let package = Package(
    name: "kokoro-helper",
    platforms: [.macOS(.v15)],
    dependencies: [.package(url: "https://github.com/FluidInference/FluidAudio.git", revision: "e560c6445ffdc42e60c7b282d162aae271f18e2a")],
    targets: [.executableTarget(name: "kokoro-helper", dependencies: [.product(name: "FluidAudio", package: "FluidAudio")])]
)
