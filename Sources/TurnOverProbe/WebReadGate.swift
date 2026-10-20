// SPDX-License-Identifier: GPL-3.0-or-later
// Gate 1 (and 2's read half): reading a web page through public text markers.
//
// What the reader will do on a page: take the document range from
// AXTextMarkerRangeForUIElement on the web area (not from the start/end
// markers — Safari returned an empty range that way in the research probe),
// pull the whole string once, find headings, links and landmarks with
// AXUIElementsForSearchPredicate, and step by word with
// AXNextWordEndTextMarkerForTextMarker. Everything is timed, and every read is
// repeated so the first (colder) pass and the warm passes can be told apart.
//
// Options: --app Safari | --bundle id | --pid N (default: frontmost app),
//          --repeat N (default 3), --words N (default 200).
// For the cold-start gate, open the page in a fresh tab, then run this within a
// second or two with VoiceOver off.
import Foundation
import ApplicationServices
import TurnOverAX
import AppKit

private func searchPredicate(_ key: String, start: AXUIElement, limit: Int) -> CFDictionary {
    [
        "AXSearchKey": key,
        "AXDirection": "AXDirectionNext",
        "AXResultsLimit": limit,
        "AXStartElement": start,
        "AXImmediateDescendantsOnly": false,
        "AXVisibleOnly": false,
    ] as CFDictionary
}

func runWebReadGate(_ args: [String]) {
    let opts = Options(args)
    let repeats = opts.int("repeat", 3)
    let wordSteps = opts.int("words", 200)

    guard let app = resolveApp(opts) else { Log.line("no target app"); return }
    Log.line("target: \(app.localizedName ?? "?") (\(app.bundleIdentifier ?? "?"), pid \(app.processIdentifier))")
    let appEl = AXUIElementCreateApplication(app.processIdentifier)
    AXUIElementSetMessagingTimeout(appEl, 5)

    // Make sure the tree is up for a non-VoiceOver client. Chromium debounces
    // this for two seconds; Electron prefers AXManualAccessibility.
    let manual = appEl.set("AXManualAccessibility", kCFBooleanTrue)
    let enhanced = appEl.set("AXEnhancedUserInterface", kCFBooleanTrue)
    Log.line("AXManualAccessibility set: \(describeError(manual)); AXEnhancedUserInterface set: \(describeError(enhanced)) (notImplemented still takes effect)")

    // Find the web area in the focused window.
    var webArea: AXUIElement?
    let find = timed { () -> AXUIElement? in
        let deadline = Date().addingTimeInterval(4)
        while Date() < deadline {
            if let win = appEl.element(kAXFocusedWindowAttribute) ?? appEl.elements(kAXWindowsAttribute).first,
               let w = win.firstDescendant(role: "AXWebArea") { return w }
            CFRunLoopRunInMode(.defaultMode, 0.2, true)
        }
        return nil
    }
    webArea = find.value
    guard let webArea else { Log.line("no AXWebArea found in \(String(format: "%.0f", find.ms)) ms"); return }
    Log.line(String(format: "web area found in %.1f ms; URL %@; title %@", find.ms,
                    (webArea.attr("AXURL") as? URL)?.absoluteString ?? "?", webArea.string(kAXTitleAttribute) ?? webArea.string(kAXDescriptionAttribute) ?? "?"))

    for pass in 1...repeats {
        Log.line("--- pass \(pass) \(pass == 1 ? "(first)" : "(warm)")")
        // Whole-document range and string.
        let range = timed { webArea.paramError("AXTextMarkerRangeForUIElement", webArea) }
        guard let r = range.value.0 else { Log.line("AXTextMarkerRangeForUIElement: \(describeError(range.value.1))"); continue }
        let string = timed { webArea.paramError("AXStringForTextMarkerRange", r) }
        let text = string.value.0 as? String ?? ""
        let length = timed { webArea.paramError("AXLengthForTextMarkerRange", r) }
        Log.line(String(format: "document: range %.2f ms, string %d chars in %.2f ms, length attr %@ in %.2f ms",
                        range.ms, text.count, string.ms, "\((length.value.0 as? NSNumber)?.intValue ?? -1)", length.ms))
        let attributed = timed { webArea.paramError("AXAttributedStringForTextMarkerRange", r) }
        let attrLen = (attributed.value.0 as? NSAttributedString)?.length ?? -1
        Log.line(String(format: "attributed string: %d chars in %.2f ms (%@)", attrLen, attributed.ms, describeError(attributed.value.1)))

        // Structural queries.
        for key in ["AXHeadingSearchKey", "AXLinkSearchKey", "AXLandmarkSearchKey", "AXTableSearchKey", "AXLiveRegionSearchKey", "AXTextFieldSearchKey", "AXButtonSearchKey"] {
            let q = timed { webArea.paramError("AXUIElementsForSearchPredicate", searchPredicate(key, start: webArea, limit: 200)) }
            let n = (q.value.0 as? [AXUIElement])?.count ?? -1
            Log.line(String(format: "%@: %d in %.2f ms (%@)", key, n, q.ms, describeError(q.value.1)))
        }
        // Chromium-only count.
        let countQ = timed { webArea.paramError("AXUIElementCountForSearchPredicate", searchPredicate("AXLinkSearchKey", start: webArea, limit: 1000)) }
        if countQ.value.1 == .success { Log.line(String(format: "AXUIElementCountForSearchPredicate(links): %@ in %.2f ms", "\((countQ.value.0 as? NSNumber)?.intValue ?? -1)", countQ.ms)) }

        // Word stepping from the start of the document.
        guard CFGetTypeID(r) == AXTextMarkerRangeGetTypeID() else { continue }
        var marker: AXTextMarker = AXTextMarkerRangeCopyStartMarker(r as! AXTextMarkerRange)
        var stepMs: [Double] = []
        var stepped = 0
        for _ in 0..<wordSteps {
            let step = timed { webArea.paramError("AXNextWordEndTextMarkerForTextMarker", marker) }
            guard let next = step.value.0, CFGetTypeID(next) == AXTextMarkerGetTypeID() else { break }
            stepMs.append(step.ms)
            marker = next as! AXTextMarker
            stepped += 1
        }
        Log.line(summarize("word step (\(stepped) steps)", stepMs))
        // Resolve the last marker back to an element and a line, the way the caret model will.
        let el = timed { webArea.paramError("AXUIElementForTextMarker", marker) }
        let line = timed { webArea.paramError("AXLineForTextMarker", marker) }
        let index = timed { webArea.paramError("AXIndexForTextMarker", marker) }
        Log.line(String(format: "marker -> element %@ in %.2f ms; line %@ in %.2f ms; index %@ in %.2f ms",
                        ((el.value.0 as! AXUIElement?)?.role) ?? describeError(el.value.1), el.ms,
                        "\((line.value.0 as? NSNumber)?.intValue ?? -1)", line.ms,
                        "\((index.value.0 as? NSNumber)?.intValue ?? -1)", index.ms))
    }
}
