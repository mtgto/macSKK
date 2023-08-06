// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Cocoa
import SwiftUI

/// 変換候補リストをフローティングモーダルで表示するパネル
final class CandidatesPanel: NSPanel {
    let viewModel: CandidatesViewModel

    init() {
        viewModel = CandidatesViewModel(candidates: [], currentPage: 0, totalPageCount: 0)
        let rootView = CandidatesView(candidates: self.viewModel)
        let viewController = NSHostingController(rootView: rootView)
        super.init(contentRect: .zero, styleMask: [.nonactivatingPanel], backing: .buffered, defer: true)
        viewController.sizingOptions = .preferredContentSize
        contentViewController = viewController
    }

    func setCandidates(_ candidates: CurrentCandidates, selected: Word?) {
        viewModel.candidates = candidates
        viewModel.selected = selected
    }

    func setSystemAnnotation(_ systemAnnotation: String, for word: Word) {
        viewModel.systemAnnotations.updateValue(systemAnnotation, forKey: word)
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
