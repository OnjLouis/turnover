// SPDX-License-Identifier: GPL-3.0-or-later
// Safari. Find (Command+F): Return, Shift+Return and Command+G read the line where the match is, and the
// virtual caret goes there (Safari says nothing and exposes no match count).
import Foundation
import ApplicationServices
import AppKit

final class SafariAppModule: AppModule {
    static let bundleID = "com.apple.Safari"

    required init(pid: pid_t, bundleIdentifier: String, appName: String) {
        super.init(pid: pid, bundleIdentifier: bundleIdentifier, appName: appName)
        let cat = "Safari"
        script("safari_findInBar", "In the Find bar: finds the next or previous match and reads it", gestures: ["kb:enter", "kb:shift+enter"], category: cat) { [weak self] g in
            g.send(); self?.readMatch()
        }.isAvailable = { [weak self] in self?.focusInFindBanner ?? false }
        script("safari_backForward", "Goes back or forward a page", gestures: ["kb:command+[", "kb:command+]"], category: cat) { [weak self] g in
            self?.navigating = (Date(), API.focusObject?.element.enclosingWebArea().flatMap { Self.address(of: $0) } ?? "")
            g.send()
        }
        // A Tab that went to Safari and brought no news at all: the page is stuck (the freeze test, 4 Oct 2026: nine
        // seconds of Tabs and arrows in silence). Say so, now and then.
        let pid = self.pid
        InputManager.passThroughWatchers.append { g in
            guard g.keyName == "tab", g.modifiers.subtracting(.shift).isEmpty,
                  NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else { return }
            PageWatch.keySent(to: pid)
        }
        // Switching tabs said nothing (a tester, 9 Oct 2026): the new tab's title, once the window shows it (NVDA reads the
        // document's title as its tab takes the focus). The tab's page then reads as usual.
        let tabKeys = ["kb:command+shift+]", "kb:command+shift+[", "kb:control+tab", "kb:control+shift+tab"] + (1...9).map { "kb:command+\($0)" }
        script("safari_switchTab", "Switches tab and says the tab's title", gestures: tabKeys, category: cat) { [weak self] g in
            guard let self else { g.send(); return }
            let app = AXUIElementCreateApplication(self.pid)
            let before = app.element(kAXFocusedWindowAttribute)?.string(kAXTitleAttribute) ?? ""
            g.send()
            Poll.until(every: 0.05, limit: 1.0, waitNotice: 5, {
                let now = app.element(kAXFocusedWindowAttribute)?.string(kAXTitleAttribute) ?? ""
                return !now.isEmpty && now != before
            }) { changed in
                let title = app.element(kAXFocusedWindowAttribute)?.string(kAXTitleAttribute) ?? ""
                Log.io("Safari: tab switch \(changed ? "to a new title" : "with the title unchanged")")
                if changed { Speech.cancel(); Speech.speakMessage(title + ", tab") }
            }
        }.isAvailable = { [weak self] in
            guard let self, API.focusPid == self.pid, !AXHandler.shared.isMenuOpen, !TurnOverMenu.shared.isOpen else { return false }
            return true
        }
        script("safari_reload", "Reloads the page and says so", gestures: ["kb:command+r"], category: cat) { g in
            g.send(); Speech.speakMessage("reload page")
        }
        script("safari_findAgain", "Finds the next or previous match and reads it", gestures: ["kb:command+g", "kb:command+shift+g"], category: cat) { [weak self] g in
            g.send(); self?.readMatch()
        }
    }

    /// Back or Forward pressed: when, and the address being left. Safari puts the focus back on the old page for a
    /// moment first; read, it was the old page's line, twice (3 Oct 2026). Those focus events are dropped.
    private var navigating: (Date, String)?

    static func address(of web: AXUIElement) -> String? {
        (web.attr("AXURL") as? URL)?.absoluteString ?? (web.attr("AXURL") as? String)
    }

    /// Whether the focus is in the Find bar, worked out on the main thread as the focus moves. The keyboard thread
    /// asked Safari itself on every Enter, and with Safari busy every key waited (E6 audit, 4 Oct 2026).
    private let findLock = NSLock()
    private var _inFind = false
    var focusInFindBanner: Bool { findLock.lock(); defer { findLock.unlock() }; return _inFind }

    override func handleEvent(_ event: Event, next: () -> Void) {
        if event.kind == .gainFocus {
            let inFind = event.obj.element.element(kAXParentAttribute)?.string(kAXDescriptionAttribute) == "Find Banner"
            findLock.lock(); _inFind = inFind; findLock.unlock()
        }
        if event.kind == .gainFocus, event.obj.axRole == "AXWebArea", let (at, old) = navigating, Date().timeIntervalSince(at) < 2, !old.isEmpty,
           Self.address(of: event.obj.element) == old {
            Log.io("Safari: focus on the page being left; not read")
            return
        }
        next()
    }

    private func readMatch() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self, let f = API.focusObject, f.pid == self.pid,
                  let window = f.element.element(kAXWindowAttribute),
                  let web = window.firstWebArea() else { return }
            let bridge = WebDocumentBridge(webArea: web)
            guard let sel = bridge.selection(), sel.1 > sel.0 else { Speech.speakMessage("not found"); return }
            let line = bridge.unitRange("AXLineTextMarkerRangeForTextMarker", at: sel.0) ?? sel
            let text = bridge.range(line.0, line.1).map { bridge.string($0) } ?? ""
            Speech.speakText(text.trimmingCharacters(in: .whitespacesAndNewlines))
            BrowseModeHandler.shared.existingDocument(for: web)?.followWebKitSelection(force: true)
        }
    }
}
