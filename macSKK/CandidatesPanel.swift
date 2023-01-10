// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Cocoa
import SwiftUI

class CandidatesPanel: NSPanel {
    init() {
        let viewController = NSHostingController(rootView: CandidatesView(words: .constant([])))
        super.init(contentRect: .zero, styleMask: [.nonactivatingPanel], backing: .buffered, defer: true)
        contentViewController = viewController
    }
}
