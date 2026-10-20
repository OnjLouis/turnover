// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
for n in CommandLine.arguments.dropFirst() {
    DistributedNotificationCenter.default().postNotificationName(NSNotification.Name(n), object: nil, userInfo: nil, deliverImmediately: true)
}
