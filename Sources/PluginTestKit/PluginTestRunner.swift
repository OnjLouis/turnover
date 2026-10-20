// SPDX-License-Identifier: GPL-3.0-or-later
// Tests that travel with a plugin (docs/PLUGIN-TOOLKIT-PLAN.md, item 5; 11 Oct 2026).
//
// A plugin may carry tests/: recorded screens (turnover-plugin record writes them, masked) and tests/expect.json, a
// list of checks: on this screen, this item (or the focus), TurnOver says this.
//
//   [ { "name": "the home icon is named", "screen": "screen-1.json",
//       "item": { "role": "AXImage", "unnamed": true, "nth": 1 },
//       "says": "^Home, button" } ]
//
// "says" and "notSays" are regular expressions over what TurnOver says for the item when it gets the focus. The
// screens are replayed (AXFixtures), so no app is needed; turnover-plugin test runs them, and TurnOver's own build runs
// the tests of every plugin it carries, so a change to TurnOver that breaks a plugin is caught before it ships.
import Foundation
import ApplicationServices
import TurnOverCore
import AXFixtures

public struct PluginTestCase: Codable {
    public var name: String?
    public var screen: String
    public var item: ElementMatch?
    public var says: String?
    public var notSays: String?
}

public enum PluginTestRunner {
    /// Run a plugin folder's tests. Lines to print, and the counts.
    public static func run(folder: URL) -> (passed: Int, failed: Int, lines: [String]) {
        var lines: [String] = []
        let plugin = ProfileStore.load(folder: folder)
        guard plugin.error == nil, let manifest = plugin.manifest else { return (0, 1, ["the plugin does not load: \(plugin.error ?? "?")"]) }
        let tests = folder.appendingPathComponent("tests")
        let expectURL = tests.appendingPathComponent("expect.json")
        guard FileManager.default.fileExists(atPath: expectURL.path) else { return (0, 0, ["\(manifest.name): no tests (tests/expect.json)"]) }
        let cases: [PluginTestCase]
        do { cases = try PluginFormat.decode([PluginTestCase].self, from: expectURL) } catch { return (0, 1, ["\(error)"]) }
        ProfileStore.shared.addTesting(plugin)
        ProfileStore.shared.replayBundle = manifest.apps.first
        ElementMatcher.searchRoots = { pid in pid >= AXReplay.floor ? [AXReplay.root].compactMap { $0 } : nil }
        defer { ProfileStore.shared.replayBundle = nil; ElementMatcher.searchRoots = nil; AXReplay.unload() }
        var passed = 0, failed = 0
        for (i, c) in cases.enumerated() {
            let label = c.name ?? "check \(i + 1)"
            let fixture: AXFixture
            do { fixture = try AXFixture.load(tests.appendingPathComponent(c.screen)) }
            catch { failed += 1; lines.append("FAIL \(label): the screen \(c.screen) does not load (\(error.localizedDescription))"); continue }
            AXReplay.load(fixture)
            let element: AXUIElement?
            if let m = c.item {
                var plain = m; plain.nth = nil
                let all = ElementMatcher.find(plain, pid: AXReplay.floor, limit: max(50, abs(m.nth ?? 1)), budget: 5)
                let n = m.nth ?? 1
                element = n < 0 ? (all.count + n >= 0 ? all[all.count + n] : nil) : (n - 1 < all.count ? all[n - 1] : nil)
            } else { element = AXReplay.focus }
            guard let e = element else { failed += 1; lines.append("FAIL \(label): no item on \(c.screen) matches"); continue }
            let said = Speech.objectPropertiesSpeech(ObjectFactory.make(e), reason: .focus).joined(separator: ", ")
            var ok = true
            if let s = c.says, said.range(of: s, options: .regularExpression) == nil { ok = false }
            if let s = c.notSays, said.range(of: s, options: .regularExpression) != nil { ok = false }
            if ok { passed += 1; lines.append("ok   \(label): \(said)") }
            else { failed += 1; lines.append("FAIL \(label): said \"\(said)\"\(c.says.map { "; expected \($0)" } ?? "")\(c.notSays.map { "; not \($0)" } ?? "")") }
        }
        return (passed, failed, lines)
    }

    /// Every plugin folder under `root` that carries tests.
    public static func folders(under root: URL) -> [URL] {
        ((try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? [])
            .filter { FileManager.default.fileExists(atPath: $0.appendingPathComponent("tests/expect.json").path) }
            .sorted { $0.path < $1.path }
    }
}
