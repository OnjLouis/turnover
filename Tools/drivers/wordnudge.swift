// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import ApplicationServices
setvbuf(stdout, nil, _IONBF, 0)
func attr(_ e: AXUIElement, _ a: String) -> AnyObject? { var v: AnyObject?; return AXUIElementCopyAttributeValue(e, a as CFString, &v) == .success ? v : nil }
func s(_ e: AXUIElement, _ a: String) -> String { (attr(e, a) as? String) ?? "" }
func kids(_ e: AXUIElement) -> [AXUIElement] { (attr(e, kAXChildrenAttribute) as? [AXUIElement]) ?? [] }
let word = NSRunningApplication.runningApplications(withBundleIdentifier: "com.microsoft.Word").first!
let ax = AXUIElementCreateApplication(word.processIdentifier)
let w = attr(ax, kAXFocusedWindowAttribute) as! AXUIElement
var layout: AXUIElement?
func find(_ e: AXUIElement) { if s(e, kAXRoleAttribute) == "AXLayoutArea" && s(e, kAXDescriptionAttribute) != "Document Thumbnails" && layout == nil { layout = e }; for c in kids(e) { find(c) } }
find(w)
func check(_ tag: String) { usleep(1_500_000); print(tag, "→ kids", kids(layout!).count) }
check("before")
switch CommandLine.arguments[1] {
case "raise": AXUIElementPerformAction(w, kAXRaiseAction as CFString); _ = AXUIElementSetAttributeValue(w, kAXMainAttribute as CFString, kCFBooleanTrue); check("raise+main")
case "activate": word.activate(options: [.activateAllWindows]); check("activate all windows")
case "frontmost": _ = AXUIElementSetAttributeValue(ax, kAXFrontmostAttribute as CFString, kCFBooleanFalse); usleep(100_000); _ = AXUIElementSetAttributeValue(ax, kAXFrontmostAttribute as CFString, kCFBooleanTrue); check("frontmost off/on")
case "notify": DistributedNotificationCenter.default().post(name: NSNotification.Name("com.apple.accessibility.api"), object: nil); check("ax notify")
default: break
}
