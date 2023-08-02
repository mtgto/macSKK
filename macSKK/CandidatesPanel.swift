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
        viewController.sizingOptions = .preferredContentSize
        contentViewController = viewController
    }

    func setWords(_ words: [Word], selected: Word?) {
        viewModel.candidates = words
        if let selected {
            viewModel.selected = SelectedWord(word: selected, systemAnnotation: nil)
        }
    }

    func show(at point: NSPoint) {
        // TODO: もしスクリーン下にはみ出す場合は setOrigin を使って左下座標を指定する。
        setFrameTopLeftPoint(point)
        if let viewController = contentViewController as? NSHostingController<CandidatesView> {
            print("content size = \(viewController.sizeThatFits(in: CGSize(width: Int.max, height: Int.max)))")
            print("intrinsicContentSize = \(viewController.view.intrinsicContentSize)")
            print("frame = \(frame)")
            print("preferredContentSize = \(viewController.preferredContentSize)")
            print("sizeThatFits = \(viewController.sizeThatFits(in: CGSize(width: 10000, height: 10000)))")
        } else {
            print("\(contentViewController!.className)")
        }
        level = .floating
        orderFrontRegardless()
    }
}
