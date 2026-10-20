// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
import ObjectiveC
setvbuf(stdout, nil, _IONBF, 0)
let base = "/System/Library/PrivateFrameworks/ScreenReader.framework/Versions/A/Frameworks/"
for f in CommandLine.arguments.dropFirst() {
    let h = dlopen(base + f + ".framework/" + f, RTLD_NOW)
    print("load \(f): \(h != nil) \(h == nil ? String(cString: dlerror()) : "")")
    var count: UInt32 = 0
    if let names = objc_copyClassNamesForImage(base + f + ".framework/Versions/A/" + f, &count) {
        for i in 0..<Int(count) { print("  " + String(cString: names[i])) }
    } else { print("  no class names") }
}
