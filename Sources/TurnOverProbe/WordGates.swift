// SPDX-License-Identifier: GPL-3.0-or-later
// Word-specific probes, 30 Sep 2026. Read-only unless stated.
//
// wordmap: Word's window holds hundreds of AXTextArea elements that share one
// text store (AXSharedTextUIElements / AXSharedCharacterRange). This maps them:
// how many, how big, how they tile the document, which one holds the caret,
// and what the bounded line reads cost on that one.
//
// watch: an AXObserver on an app for the notifications a reader follows, so
// the owner can arrow through the document and the log shows what arrives.
import Foundation
import ApplicationServices
import TurnOverAX
import AppKit

private func textAreas(in win: AXUIElement, cap: Int = 6000) -> [AXUIElement] {
    var out: [AXUIElement] = []
    var queue: [AXUIElement] = [win]
    var visited = 0
    while !queue.isEmpty && visited < cap {
        let e = queue.removeFirst()
        visited += 1
        if e.role == "AXTextArea" { out.append(e) }
        queue.append(contentsOf: e.elements(kAXChildrenAttribute))
    }
    return out
}

func runWordMapGate(_ args: [String]) {
    let opts = Options(args)
    guard let app = resolveApp(opts) ?? NSRunningApplication.runningApplications(withBundleIdentifier: "com.microsoft.Word").first else {
        Log.line("Word not running"); return
    }
    let appEl = AXUIElementCreateApplication(app.processIdentifier)
    AXUIElementSetMessagingTimeout(appEl, 5)
    guard let win = appEl.element(kAXFocusedWindowAttribute) else { Log.line("no focused window"); return }
    Log.line("window \"\(win.string(kAXTitleAttribute) ?? "?")\"")

    let found = timed { textAreas(in: win) }
    let areas = found.value
    Log.line(String(format: "%d AXTextArea elements found in %.0f ms", areas.count, found.ms))

    struct Info { let index: Int; let chars: Int; let shared: CFRange?; let selected: CFRange?; let visible: CFRange?; let desc: String; let y: Double }
    var infos: [Info] = []
    let scan = timed {
        for (i, a) in areas.enumerated() {
            var pos = CGPoint.zero
            if let p = a.attr(kAXPositionAttribute), CFGetTypeID(p) == AXValueGetTypeID() { AXValueGetValue(p as! AXValue, .cgPoint, &pos) }
            infos.append(Info(index: i, chars: a.int("AXNumberOfCharacters") ?? -1,
                              shared: cfRange(a.attr("AXSharedCharacterRange")),
                              selected: cfRange(a.attr(kAXSelectedTextRangeAttribute)),
                              visible: cfRange(a.attr(kAXVisibleCharacterRangeAttribute)),
                              desc: a.string(kAXDescriptionAttribute) ?? "", y: pos.y))
        }
    }
    Log.line(String(format: "scanned all (%d attributes each) in %.0f ms", 5, scan.ms))
    let nonEmpty = infos.filter { $0.chars > 0 }
    let total = nonEmpty.reduce(0) { $0 + $1.chars }
    Log.line("non-empty: \(nonEmpty.count); characters across them: \(total); empty: \(infos.count - nonEmpty.count)")
    let descs = Dictionary(grouping: infos, by: { $0.desc.replacingOccurrences(of: "[0-9]+", with: "#", options: .regularExpression) })
    for (d, list) in descs.sorted(by: { $0.value.count > $1.value.count }).prefix(12) {
        Log.line("  \(list.count)\tdesc \"\(d)\"  chars: \(list.map { $0.chars }.prefix(6).map(String.init).joined(separator: ","))…")
    }
    // How they tile: first 12 non-empty by shared range.
    for info in nonEmpty.prefix(12) {
        Log.line(String(format: "  #%d chars %d shared %@ visible %@ selected %@ y %.0f \"%@\"", info.index, info.chars,
                        info.shared.map { "\($0.location)+\($0.length)" } ?? "-", info.visible.map { "\($0.location)+\($0.length)" } ?? "-",
                        info.selected.map { $0.location == Int.max ? "none" : "\($0.location)+\($0.length)" } ?? "-", info.y, info.desc))
    }

    // Which one holds the caret?
    let caretAreas = infos.filter { ($0.selected?.location ?? Int.max) != Int.max }
    Log.line("text areas reporting a selection: \(caretAreas.count) -> \(caretAreas.prefix(5).map { "#\($0.index) at \($0.selected!.location)+\($0.selected!.length) (\($0.desc))" })")
    guard let home = caretAreas.first(where: { $0.desc != "" && !$0.desc.hasPrefix("Header") && !$0.desc.hasPrefix("Footer") }) ?? caretAreas.first else {
        Log.line("no text area holds the caret; click into the document body and run again"); return
    }
    let el = areas[home.index]
    let sel = home.selected!
    Log.line("--- caret area #\(home.index) \"\(home.desc)\": \(home.chars) chars, caret at \(sel.location)")
    var names: CFArray?
    if AXUIElementCopyAttributeNames(el, &names) == .success, let list = names as? [String] { Log.line("attributes: \(list.joined(separator: ", "))") }
    var pnames: CFArray?
    if AXUIElementCopyParameterizedAttributeNames(el, &pnames) == .success, let list = pnames as? [String] { Log.line("parameterized: \(list.joined(separator: ", "))") }
    let shared = timed { el.elements("AXSharedTextUIElements") }
    Log.line(String(format: "AXSharedTextUIElements: %d elements in %.2f ms", shared.value.count, shared.ms))

    // The reader's line read, 20 times, at the caret.
    var lineMs: [Double] = []
    var lineText = ""
    for _ in 0..<20 {
        let t = timed { () -> String in
            guard let n = (el.param("AXLineForIndex", sel.location as CFNumber) as? NSNumber)?.intValue,
                  let r = cfRange(el.param("AXRangeForLine", n as CFNumber)),
                  let s = el.param("AXStringForRange", axRangeValue(r.location, r.length)) as? String else { return "" }
            return s
        }
        lineMs.append(t.ms); lineText = t.value
    }
    Log.line(summarize("line read at caret (LineForIndex + RangeForLine + StringForRange)", lineMs))
    Log.line("line text: \"\(lineText.trimmingCharacters(in: .whitespacesAndNewlines).prefix(100))\"")
    let around = timed { el.paramError("AXStringForRange", axRangeValue(max(0, sel.location - 300), 600)) }
    Log.line(String(format: "600 chars around caret: %d chars in %.2f ms (%@)", (around.value.0 as? String)?.count ?? -1, around.ms, describeError(around.value.1)))
    let attributed = timed { el.paramError("AXAttributedStringForRange", axRangeValue(sel.location, min(200, home.chars - sel.location))) }
    Log.line(String(format: "attributed 200 chars: %.2f ms (%@)", attributed.ms, describeError(attributed.value.1)))
    let value = timed { el.attrError(kAXValueAttribute) }
    Log.line(String(format: "AXValue of this area: %d UTF-16 units in %.2f ms (%@)", (value.value.0 as? String)?.utf16.count ?? -1, value.ms, describeError(value.value.1)))
    if let sh = home.shared { Log.line("shared character range of this area: \(sh.location)+\(sh.length)") }
}

private var watchCount = 0
private let watchCallback: AXObserverCallbackWithInfo = { _, el, name, info, _ in
    watchCount += 1
    let role = el.role
    let desc = el.string(kAXDescriptionAttribute) ?? ""
    let sel = cfRange(el.attr(kAXSelectedTextRangeAttribute)).map { $0.location == Int.max ? "none" : "\($0.location)+\($0.length)" } ?? "-"
    var extra = ""
    if unsafeBitCast(info, to: Int.self) != 0, let d = info as NSDictionary? {
        extra = " info keys: \(d.allKeys.map { "\($0)" }.joined(separator: ","))"
    }
    if watchCount <= 400 {
        Log.line("NOTIF \(name as String)  \(role) \"\(desc.prefix(40))\" selection \(sel)\(extra)")
    }
}

func runWatchGate(_ args: [String]) {
    let opts = Options(args)
    let seconds = opts.double("seconds", 90)
    guard let app = resolveApp(opts) else { Log.line("no target app"); return }
    Log.line("watching \(app.localizedName ?? "?") pid \(app.processIdentifier) for \(Int(seconds)) s — arrow through the document now")
    let appEl = AXUIElementCreateApplication(app.processIdentifier)
    AXUIElementSetMessagingTimeout(appEl, 2)
    var obs: AXObserver?
    guard AXObserverCreateWithInfoCallback(app.processIdentifier, watchCallback, &obs) == .success, let obs else { Log.line("observer failed"); return }
    for n in ["AXFocusedUIElementChanged", "AXSelectedTextChanged", "AXValueChanged", "AXFocusedWindowChanged", "AXLayoutChanged",
              "AXAnnouncementRequested", "AXTitleChanged", "AXSelectedChildrenChanged", "AXMenuOpened", "AXMenuClosed", "AXCreated", "AXUIElementDestroyed"] {
        let r = AXObserverAddNotification(obs, appEl, n as CFString, nil)
        if r != .success { Log.line("add \(n): \(describeError(r))") }
    }
    CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(obs), .defaultMode)
    CFRunLoopRunInMode(.defaultMode, seconds, false)
    Log.line("total notifications: \(watchCount)")
}
