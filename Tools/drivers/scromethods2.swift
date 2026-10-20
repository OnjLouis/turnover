// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
import ObjectiveC
setvbuf(stdout, nil, _IONBF, 0)
_ = dlopen("/System/Library/PrivateFrameworks/ScreenReader.framework/Versions/A/Frameworks/BrailleTranslation.framework/BrailleTranslation", RTLD_NOW)
for name in CommandLine.arguments.dropFirst() {
    guard let c = NSClassFromString(name) else { print("== \(name): not found"); continue }
    print("== \(name) : \(class_getSuperclass(c).map(NSStringFromClass) ?? "-")")
    var n: UInt32 = 0
    if let ms = class_copyMethodList(object_getClass(c), &n) { for i in 0..<Int(n) { print("  + " + NSStringFromSelector(method_getName(ms[i])) + "  " + String(cString: method_getTypeEncoding(ms[i])!)) } }
    if let ms = class_copyMethodList(c, &n) { for i in 0..<Int(n) { print("  - " + NSStringFromSelector(method_getName(ms[i])) + "  " + String(cString: method_getTypeEncoding(ms[i])!)) } }
}
