// SPDX-License-Identifier: GPL-3.0-or-later
import CoreGraphics
var count: UInt32 = 0; CGGetOnlineDisplayList(0, nil, &count)
var list = [CGDirectDisplayID](repeating: 0, count: Int(count)); CGGetOnlineDisplayList(count, &list, &count)
for d in list { let size = CGDisplayGammaTableCapacity(d); var r = [CGGammaValue](repeating: 0, count: Int(size)), g = r, b = r; var n: UInt32 = 0
  _ = CGGetDisplayTransferByTable(d, size, &r, &g, &b, &n); print("display \(d): max \(max(r.max() ?? 0, g.max() ?? 0, b.max() ?? 0))") }
