// SPDX-License-Identifier: GPL-3.0-or-later
// turnover-tests: TurnOver's unit tests (8 Oct 2026, from the team review). No XCTest: a plain executable that
// build.sh runs before installing, so a failing test stops a build going out. Pure functions first; then the
// views against recorded accessibility trees (Tests/Fixtures) replayed through AXReplayShim.
//
//   turnover-tests [name-filter] [-v]
import Foundation

enum Harness {
    static var passed = 0
    static var failed = 0
    static var current = ""
    static var verbose = CommandLine.arguments.contains("-v")
    static var filter: String? = CommandLine.arguments.dropFirst().first { !$0.hasPrefix("-") }
    static var failures: [String] = []

    static func test(_ name: String, _ body: () throws -> Void) {
        if let f = filter, !name.localizedCaseInsensitiveContains(f) { return }
        current = name
        let before = failed
        do { try body() } catch { fail("threw \(error)") }
        if failed == before { passed += 1; if verbose { print("ok   \(name)") } }
        else { print("FAIL \(name)") }
    }
    static func fail(_ what: String, file: String = #fileID, line: Int = #line) {
        failed += 1
        failures.append("\(current): \(what) (\(file):\(line))")
        print("     \(what) (\(file):\(line))")
    }
    static func finish() -> Never {
        print("\(passed) passed, \(failed) failed")
        exit(failed == 0 ? 0 : 1)
    }
}

func check(_ condition: @autoclosure () -> Bool, _ what: String, file: String = #fileID, line: Int = #line) {
    if !condition() { Harness.fail(what, file: file, line: line) }
}
func expect<T: Equatable>(_ got: T, _ want: T, _ what: String = "", file: String = #fileID, line: Int = #line) {
    if got != want { Harness.fail("\(what)\(what.isEmpty ? "" : ": ")got \(String(reflecting: got)), wanted \(String(reflecting: want))", file: file, line: line) }
}
func test(_ name: String, _ body: () throws -> Void) { Harness.test(name, body) }

/// A fixture by name, from Tests/Fixtures beside the sources.
func fixtureURL(_ name: String) -> URL {
    URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Tests/Fixtures/\(name).json")
}
