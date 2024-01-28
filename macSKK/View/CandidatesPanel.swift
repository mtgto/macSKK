// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Cocoa
import SwiftUI

/// 変換候補リストをフローティングモーダルで表示するパネル
@MainActor
final class CandidatesPanel: NSPanel {
    let viewModel: CandidatesViewModel
    var cursorPosition: NSRect = .zero

    /**
     * - Parameters:
     *   - showAnnotationPopover: パネル表示時に注釈を表示するかどうか
     */
    init(showAnnotationPopover: Bool) {
        viewModel = CandidatesViewModel(candidates: [],
                                        currentPage: 0,
                                        totalPageCount: 0,
                                        showAnnotationPopover: showAnnotationPopover)
        let rootView = CandidatesView(candidates: self.viewModel)
        let viewController = NSHostingController(rootView: rootView)
        // borderlessにしないとdeactivateServerが呼ばれてしまう
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        backgroundColor = .clear
        contentViewController = viewController
    }

    func setCandidates(_ candidates: CurrentCandidates, selected: Candidate?) {
        viewModel.candidates = candidates
        viewModel.selected = selected
    }

    func setSystemAnnotation(_ systemAnnotation: String, for word: Word.Word) {
        viewModel.systemAnnotations[word] = systemAnnotation
    }

    func setCursorPosition(_ cursorPosition: NSRect) {
        self.cursorPosition = cursorPosition
    }

    func setShowAnnotationPopover(_ showAnnotationPopover: Bool) {
        self.viewModel.showAnnotationPopover = showAnnotationPopover
    }

    /**
     * 表示する。スクリーンからはみ出す位置が指定されている場合は自動で調整する。
     *
     * - 下にはみ出る場合: テキストの上側に表示する
     * - 右にはみ出す場合: スクリーン右端に接するように表示する
     */
    func show() {
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
        let height: CGFloat
        if case let .panel(words, _, _) = viewModel.candidates {
            height = CGFloat(words.count) * CandidatesView.lineHeight + CandidatesView.footerHeight
        } else {
            // FIXME: 短い文のときにはそれに合わせて高さを縮める
            height = 200
        }
        setContentSize(NSSize(width: width, height: height))
        var origin = cursorPosition.origin
        if let mainScreen = NSScreen.main {
            if origin.x + width > mainScreen.visibleFrame.size.width {
                origin.x = mainScreen.frame.size.width - width
            }
        }
        if origin.y > height {
            setFrameTopLeftPoint(origin)
        } else {
            // スクリーン下にはみ出す場合はテキスト入力位置の上に表示する
            setFrameOrigin(CGPoint(x: origin.x, y: origin.y + cursorPosition.size.height))
        }
        level = .floating
        orderFrontRegardless()
    }
}
