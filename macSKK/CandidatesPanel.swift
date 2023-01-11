// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Cocoa
import SwiftUI

final class CandidatesPanel: NSPanel {
    private let viewModel: CandidatesViewModel

    init(candidates: [Word]) {
        viewModel = CandidatesViewModel(candidates: candidates)
        let viewController = NSHostingController(rootView: CandidatesView(candidates: viewModel))
        super.init(contentRect: .zero, styleMask: [.nonactivatingPanel], backing: .buffered, defer: true)
        contentViewController = viewController
    }
    
    func setWords(_ words: [Word]) {
        viewModel.candidates = words
        viewModel.selected = words.first
    }
}
