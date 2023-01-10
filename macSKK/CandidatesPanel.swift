// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Cocoa
import SwiftUI

class CandidatesPanel: NSPanel {
    init() {
        let words = [Word("ほげ")]
        let viewModel = CandidatesViewModel(candidates: [Word("ほげ")])
        let viewController = NSHostingController(rootView: CandidatesView(candidates: viewModel))
        super.init(contentRect: .zero, styleMask: [.nonactivatingPanel], backing: .buffered, defer: true)
        contentViewController = viewController
    }
}
