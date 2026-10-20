// SPDX-License-Identifier: GPL-3.0-or-later
// The status menus (Windows: the notification area, Windows+B), as a spoken list.
// Option+B gathers every application's menu bar extras (Control Center's Wi-Fi,
// battery and clock, other apps' items, TurnOver's own) in screen order, left to
// right. Enter presses the item and its menu is read as any menu is. TurnOver's
// own item opens the spoken TurnOver menu: TurnOver never makes accessibility calls
// into its own process, which would block its main thread.
//
// The system's Control-F8 ("move focus to status menus") moved nothing when
// measured on 1 Oct 2026, which is why TurnOver lists them itself.
import Foundation
import AppKit
import ApplicationServices

public enum StatusMenus {
    /// The status item just opened from the list: its menu carries no name of its own ("a VPN app's menu").
    public static var lastOpened: (String, Date)?
    struct Extra { let element: AXUIElement; let pid: pid_t; let name: String; let x: Double }

    /// The names, in order, for tests.
    public static func names() -> [String] { gather().map(\.name) }

    static func gather() -> [Extra] {
        let me = getpid()
        // Web content processes never own status items and answer slowly; everything else is asked at once.
        let apps = NSWorkspace.shared.runningApplications.filter {
            $0.processIdentifier != me && !($0.bundleIdentifier ?? "").hasPrefix("com.apple.WebKit")
        }
        let found = Locked([[Extra]](repeating: [], count: apps.count))
        DispatchQueue.concurrentPerform(iterations: apps.count) { i in
            let app = apps[i]
            let ax = AXUIElementCreateApplication(app.processIdentifier)
            AXUIElementSetMessagingTimeout(ax, 0.25)
            guard let bar = ax.element("AXExtrasMenuBar") else { return }
            // Each element keeps the timeout it was given: the bar and its items too, or a hung app costs 2 s apiece.
            AXUIElementSetMessagingTimeout(bar, 0.25)
            var mine: [Extra] = []
            for outer in bar.elements(kAXChildrenAttribute) {
                AXUIElementSetMessagingTimeout(outer, 0.25)
                // macOS's own items (MenuBarAgent) are unlabelled holders of a labelled item: Wi-Fi, Battery, Clock.
                var item = outer
                if (outer.string(kAXDescriptionAttribute) ?? "").isEmpty, (outer.string(kAXTitleAttribute) ?? "").isEmpty,
                   let inner = outer.elements(kAXChildrenAttribute).first(where: { !($0.string(kAXDescriptionAttribute) ?? $0.string(kAXTitleAttribute) ?? "").isEmpty }) {
                    item = inner
                }
                var x = 0.0
                if let v = item.attr(kAXPositionAttribute), CFGetTypeID(v as CFTypeRef) == AXValueGetTypeID() { var p = CGPoint.zero; axValue(v, .cgPoint, &p); x = p.x }
                mine.append(Extra(element: item, pid: app.processIdentifier, name: name(of: item, app: app), x: x))
            }
            found.value[i] = mine
        }
        return found.value.flatMap { $0 }.sorted { $0.x < $1.x }
    }

    /// A spoken name: the item's label, else its owner's name, with the tooltip when it says more ("a Bluetooth device, Disconnected").
    nonisolated static func name(of item: AXUIElement, app: NSRunningApplication) -> String {
        func clean(_ s: String?) -> String? {
            let t = (s ?? "").trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "-–")))
            return t.isEmpty || t.lowercased() == "menu" ? nil : t
        }
        let help = clean(item.string(kAXHelpAttribute))?.replacingOccurrences(of: "\n", with: ", ")
        if let label = clean(item.string(kAXDescriptionAttribute)) ?? clean(item.string(kAXTitleAttribute)) {
            if let help, !help.hasPrefix(label) { return "\(label), \(help)" }
            return label
        }
        // No label at all (Control Center's items on macOS 26.5: every one was "Control Center", a tester, 8 Oct 2026):
        // the identifier's last part, as words ("com.apple.menuextra.battery" → "battery").
        if let id = item.string(kAXIdentifierAttribute) ?? item.element(kAXParentAttribute)?.string(kAXIdentifierAttribute),
           let last = id.split(separator: ".").last, !last.isEmpty, last.count < 40 {
            var words = ""
            for c in last { if c.isUppercase, !words.isEmpty { words += " " }; words.append(c == "_" || c == "-" ? " " : c) }
            let w = words.lowercased()
            if let help { return "\(w), \(help)" }
            return w
        }
        let owner: String
        switch app.bundleIdentifier ?? "" {
        case "com.apple.TextInputMenuAgent": owner = "Input menu"
        case "com.apple.MenuBarAgent": owner = "System item"
        default: owner = app.localizedName ?? "Item"
        }
        return help.map { "\(owner), \($0)" } ?? owner
    }

    public static func openList() {
        let extras = gather()
        var items = extras.map { e in
            MenuItem(e.name, .action {
                AXHandler.shared.observe(e.pid)
                StatusMenus.lastOpened = (e.name, Date())
                let r = AXUIElementPerformAction(e.element, kAXPressAction as CFString)
                Log.io("status menus: press \"\(Log.words(e.name))\" → \(r.rawValue)")
                // A slow app (a VPN app) answers "cannot complete" and opens its menu anyway: only a menu that never
                // appears is a failure.
                if r != .success {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        if !AXHandler.shared.isMenuOpen { Speech.speakMessage("could not open \(e.name)") }
                    }
                }
            })
        }
        // TurnOver's own item, at the right of the others it sits beside.
        items.append(MenuItem("TurnOver", .action { DispatchQueue.main.async { TurnOverMenu.shared.open() } }))
        Log.io("status menus: \(extras.count) items")
        TurnOverMenu.shared.openList("Status menus", items: items)
    }
}
