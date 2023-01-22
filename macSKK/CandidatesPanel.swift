// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Cocoa
import SwiftUI

final class CandidatesPanel: NSPanel {
    let viewModel: CandidatesViewModel

    init() {
        viewModel = CandidatesViewModel(candidates: [])
        let viewController = NSHostingController(rootView: CandidatesView(candidates: viewModel))
        super.init(contentRect: .zero, styleMask: [.nonactivatingPanel], backing: .buffered, defer: true)
        viewController.preferredContentSize = viewController.view.intrinsicContentSize
        viewController.sizingOptions = .preferredContentSize
        contentViewController = viewController
        minSize = CGSize(width: 320, height: 20)
    }

    func setWords(_ words: [Word], selected: Word?) {
        viewModel.candidates = words
        viewModel.selected = selected
    }

    func show(at point: NSPoint) {
        setFrameTopLeftPoint(point)
        if let viewController = contentViewController as? NSHostingController<CandidatesView> {
            print("content size = \(viewController.sizeThatFits(in: CGSize(width: Int.max, height: Int.max)))")
            print("intrinsicContentSize = \(viewController.view.intrinsicContentSize)")
        } else {
            print("\(contentViewController!.className)")
        }
        level = .floating
        orderFrontRegardless()
    }
}
