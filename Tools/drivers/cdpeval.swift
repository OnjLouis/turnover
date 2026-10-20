// SPDX-License-Identifier: GPL-3.0-or-later
// cdpeval <port> <title-prefix> <javascript>: Runtime.evaluate in the Chromium page whose title starts so, on the
// loopback debugging port; prints the result. For looking at Steam's pages (16 Oct 2026). Loopback only.
import Foundation
let args = CommandLine.arguments
guard args.count >= 4, let port = Int(args[1]) else { print("usage: cdpeval <port> <title-prefix> <js>"); exit(2) }
let data = try! Data(contentsOf: URL(string: "http://127.0.0.1:\(port)/json/list")!)
let targets = try! JSONSerialization.jsonObject(with: data) as! [[String: Any]]
guard let t = targets.first(where: { ($0["title"] as? String ?? "").hasPrefix(args[2]) }), let ws = t["webSocketDebuggerUrl"] as? String,
      let url = URL(string: ws), ["127.0.0.1", "localhost"].contains(url.host ?? "") else { print("no page titled \(args[2])"); exit(1) }
let task = URLSession.shared.webSocketTask(with: url); task.resume()
let msg: [String: Any] = ["id": 1, "method": "Runtime.evaluate", "params": ["expression": args[3], "returnByValue": true]]
let body = String(data: try! JSONSerialization.data(withJSONObject: msg), encoding: .utf8)!
let sem = DispatchSemaphore(value: 0)
task.send(.string(body)) { e in if let e { print("send: \(e)"); exit(1) } }
task.receive { r in
    if case .success(.string(let s)) = r, let d = s.data(using: .utf8), let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any] {
        let res = (j["result"] as? [String: Any])?["result"] as? [String: Any]
        if let v = res?["value"] { if let str = v as? String { print(str) } else { print(String(data: try! JSONSerialization.data(withJSONObject: v, options: .prettyPrinted), encoding: .utf8)!) } }
        else { print(s.prefix(2000)) }
    } else { print("receive: \(r)") }
    sem.signal()
}
_ = sem.wait(timeout: .now() + 10)
