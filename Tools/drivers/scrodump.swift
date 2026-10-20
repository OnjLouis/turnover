// SPDX-License-Identifier: GPL-3.0-or-later
// List the Objective-C interface of one of macOS's braille drivers (methods and protocols), to see how
// VoiceOver drives a display.
import Foundation
import ObjectiveC
let path = CommandLine.arguments[1]
guard let b = Bundle(path: path), b.load(), let cls = b.principalClass else { print("could not load"); exit(1) }
func dump(_ c: AnyClass, _ title: String) {
    print("== \(title) \(NSStringFromClass(c))")
    var n: UInt32 = 0
    if let ms = class_copyMethodList(c, &n) { for i in 0..<Int(n) { print("  - " + NSStringFromSelector(method_getName(ms[i])) + "  " + String(cString: method_getTypeEncoding(ms[i])!)) } }
    if let ms = class_copyMethodList(object_getClass(c), &n) { for i in 0..<Int(n) { print("  + " + NSStringFromSelector(method_getName(ms[i]))) } }
    if let ps = class_copyProtocolList(c, &n) { for i in 0..<Int(n) { print("  protocol " + String(cString: protocol_getName(ps[i]))) } }
}
var c: AnyClass? = cls
while let k = c, NSStringFromClass(k) != "NSObject" { dump(k, "class"); c = class_getSuperclass(k) }
