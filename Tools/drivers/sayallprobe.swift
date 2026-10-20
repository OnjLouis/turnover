// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import ApplicationServices
func attr(_ e: AXUIElement, _ a: String) -> AnyObject? { var v: AnyObject?; return AXUIElementCopyAttributeValue(e, a as CFString, &v) == .success ? v : nil }
func param(_ e: AXUIElement, _ a: String, _ p: AnyObject) -> AnyObject? { var v: AnyObject?; return AXUIElementCopyParameterizedAttributeValue(e, a as CFString, p, &v) == .success ? v : nil }
func rangeVal(_ s: Int, _ l: Int) -> AXValue { var r = CFRange(location: s, length: l); return AXValueCreate(.cfRange, &r)! }
let pid = NSRunningApplication.runningApplications(withBundleIdentifier: "com.microsoft.Word").first!.processIdentifier
let app = AXUIElementCreateApplication(pid)
var areas: [AXUIElement] = []
func walk(_ e: AXUIElement, _ d: Int) {
    if d > 12 { return }
    if (attr(e, "AXRole") as? String) == "AXTextArea", (attr(e, "AXDescription") as? String ?? "").isEmpty || true {
        if let n = attr(e, "AXNumberOfCharacters") as? Int, n > 0 { areas.append(e); return }
    }
    for c in (attr(e, "AXChildren") as? [AXUIElement]) ?? [] { walk(c, d + 1) }
}
for w in (attr(app, "AXWindows") as? [AXUIElement]) ?? [] where (attr(w, "AXTitle") as? String ?? "").contains("say all") { walk(w, 0) }
print("areas \(areas.count)")
for (i, a) in areas.enumerated() {
    let n = attr(a, "AXNumberOfCharacters") as? Int ?? -1
    let vr = attr(a, "AXVisibleCharacterRange")
    let shared = (attr(a, "AXSharedTextUIElements") as? [AXUIElement])?.count ?? 0
    print("area \(i): n \(n) visible \(String(describing: vr)) shared \(shared) desc \(attr(a, "AXDescription") as? String ?? "")")
}
guard let a = areas.first else { exit(1) }
let n = attr(a, "AXNumberOfCharacters") as! Int
// Read paragraphs the way TextInfo.paragraphOffsets does, through area 0.
var pos = 0, k = 0
while pos < n && k < 40 {
    let s = param(a, "AXStringForRange", rangeVal(pos, min(4000, n - pos))) as? String ?? "<nil>"
    let u = Array(s.utf16)
    var e = 0; while e < u.count && u[e] != 13 && u[e] != 10 && u[e] != 0x2029 && u[e] != 0x0B && u[e] != 12 { e += 1 }
    print("para at \(pos): \(e) chars, read \(u.count): \(String(s.prefix(40)).debugDescription) … \(String(String(utf16CodeUnits: Array(u[max(0,e-30)..<e]), count: min(30,e))).debugDescription)")
    if e >= u.count { break }
    pos += e + 1; k += 1
}
