// SPDX-License-Identifier: GPL-3.0-or-later
// cdp: evaluate one JavaScript expression in a page on a Chromium debugging port and print the result.
//   cdp <port> <title-substring> <expression>
// Read-only use for TurnOver's game work (8 Oct 2026). Awaits a promise; prints JSON.
import Foundation
let a = CommandLine.arguments
guard a.count >= 4, let port = Int(a[1]) else { print("usage: cdp <port> <title> <expr>"); exit(2) }
struct T: Decodable { let title: String?; let webSocketDebuggerUrl: String? }
let data = try! Data(contentsOf: URL(string: "http://127.0.0.1:\(port)/json/list")!)
let targets = try! JSONDecoder().decode([T].self, from: data)
guard let t = targets.first(where: { $0.title == a[2] }) ?? targets.first(where: { ($0.title ?? "").contains(a[2]) }), let ws = t.webSocketDebuggerUrl, let url = URL(string: ws) else { print("no page titled \(a[2])"); exit(1) }
let task = URLSession.shared.webSocketTask(with: url); task.resume()
let msg: [String: Any] = ["id": 1, "method": "Runtime.evaluate", "params": ["expression": a[3], "awaitPromise": true, "returnByValue": true]]
task.send(.string(String(decoding: try! JSONSerialization.data(withJSONObject: msg), as: UTF8.self))) { e in if let e { print("send: \(e)"); exit(1) } }
func recv() {
    task.receive { r in
        switch r {
        case .failure(let e): print("recv: \(e)"); exit(1)
        case .success(let m):
            var s = ""; if case .string(let x) = m { s = x }; if case .data(let d) = m { s = String(decoding: d, as: UTF8.self) }
            if let o = try? JSONSerialization.jsonObject(with: Data(s.utf8)) as? [String: Any], o["id"] as? Int == 1 {
                let res = (o["result"] as? [String: Any]) ?? o
                if let d = try? JSONSerialization.data(withJSONObject: res, options: [.prettyPrinted, .sortedKeys]) { print(String(decoding: d, as: UTF8.self)) }
                exit(0)
            }
            recv()
        }
    }
}
recv()
DispatchQueue.global().asyncAfter(deadline: .now() + 8) { print("timeout"); exit(1) }
RunLoop.main.run()
