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
        contentViewController = viewController
    }

    func setCandidates(_ candidates: CurrentCandidates, selected: Word?) {
        viewModel.candidates = candidates
        viewModel.selected = selected
    }

    func setSystemAnnotation(_ systemAnnotation: String, for word: Word) {
        viewModel.systemAnnotations.updateValue(systemAnnotation, forKey: word)
    }

    func show(cursorPosition: NSRect) {
        guard let viewController = contentViewController as? NSHostingController<CandidatesView> else {
            fatalError("ビューコントローラの状態が壊れている")
        }
        #if DEBUG
        print("content size = \(viewController.sizeThatFits(in: CGSize(width: Int.max, height: Int.max)))")
        print("intrinsicContentSize = \(viewController.view.intrinsicContentSize)")
        print("frame = \(frame)")
        print("preferredContentSize = \(viewController.preferredContentSize)")
        print("sizeThatFits = \(viewController.sizeThatFits(in: CGSize(width: 10000, height: 10000)))")
        #endif
        let width = viewController.rootView.minWidth()
        let height = CGFloat(self.viewModel.candidates.words.count) * CandidatesView.lineHeight + CandidatesView.footerHeight
        setContentSize(NSSize(width: width, height: height))
        if cursorPosition.origin.y > height {
            setFrameTopLeftPoint(cursorPosition.origin)
        } else {
            // スクリーン下にはみ出す場合はテキスト入力位置の上に表示する
            setFrameOrigin(CGPoint(x: cursorPosition.origin.x, y: cursorPosition.origin.y + cursorPosition.size.height))
        }
        level = .floating
        orderFrontRegardless()
    }
}
