// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
import AppKit

/// One line at a time, to stdout and to a file. The file is the deliverable:
/// probes run while the owner cannot see the screen, and the log is what is
/// read afterwards.
nonisolated enum Log {
    nonisolated(unsafe) private static var handle: FileHandle?
    private static let started = Date()
    nonisolated(unsafe) static var path: String = ""

    static func open(gate: String) {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TurnOver/logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "")
        let url = dir.appendingPathComponent("probe-\(gate)-\(stamp).log")
        FileManager.default.createFile(atPath: url.path, contents: nil)
        handle = try? FileHandle(forWritingTo: url)
        path = url.path
        print("Log: \(url.path)")
    }

    static func line(_ text: String) {
        let t = String(format: "%8.3f", Date().timeIntervalSince(started))
        let out = "[\(t)] \(text)\n"
        print(out, terminator: "")
        try? handle?.write(contentsOf: Data(out.utf8))
    }

    static func close() {
        line("end")
        try? handle?.close()
    }
}

func voiceOverRunning() -> Bool {
    NSWorkspace.shared.isVoiceOverEnabled
}

/// Simple option parsing: `--name value` pairs and bare `--flag`s.
struct Options {
    var values: [String: String] = [:]
    var flags: Set<String> = []
    init(_ args: [String]) {
        var i = 0
        while i < args.count {
            let a = args[i]
            if a.hasPrefix("--") {
                let key = String(a.dropFirst(2))
                if i + 1 < args.count, !args[i + 1].hasPrefix("--") {
                    values[key] = args[i + 1]; i += 2
                } else {
                    flags.insert(key); i += 1
                }
            } else { i += 1 }
        }
    }
    func double(_ key: String, _ fallback: Double) -> Double { values[key].flatMap(Double.init) ?? fallback }
    func int(_ key: String, _ fallback: Int) -> Int { values[key].flatMap(Int.init) ?? fallback }
    func string(_ key: String) -> String? { values[key] }
    func has(_ key: String) -> Bool { flags.contains(key) }
}

/// Percentiles over a list of millisecond samples, for the summary lines.
func summarize(_ name: String, _ samples: [Double]) -> String {
    guard !samples.isEmpty else { return "\(name): no samples" }
    let s = samples.sorted()
    func p(_ q: Double) -> Double { s[min(s.count - 1, Int(Double(s.count) * q))] }
    return String(format: "%@: n=%d min=%.2f p50=%.2f p95=%.2f max=%.2f ms",
                  name, s.count, s[0], p(0.5), p(0.95), s[s.count - 1])
}

/// Find a running app by bundle id or by name, or take a pid.
func resolveApp(_ opts: Options) -> NSRunningApplication? {
    if let pid = opts.string("pid").flatMap({ pid_t($0) }) {
        return NSRunningApplication(processIdentifier: pid)
    }
    if let bundle = opts.string("bundle") {
        return NSRunningApplication.runningApplications(withBundleIdentifier: bundle).first
    }
    if let name = opts.string("app") {
        return NSWorkspace.shared.runningApplications.first { $0.localizedName?.localizedCaseInsensitiveCompare(name) == .orderedSame }
    }
    return NSWorkspace.shared.frontmostApplication
}
