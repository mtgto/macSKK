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
     *   - candidatesFontSize: 変換候補のフォントサイズ
     */
    init(showAnnotationPopover: Bool, candidatesFontSize: Int, annotationFontSize: Int) {
        viewModel = CandidatesViewModel(candidates: [],
                                        currentPage: 0,
                                        totalPageCount: 0,
                                        showAnnotationPopover: showAnnotationPopover,
                                        candidatesFontSize: CGFloat(candidatesFontSize),
                                        annotationFontSize: CGFloat(annotationFontSize))
        let rootView = CandidatesView(candidates: self.viewModel)
        let viewController = NSHostingController(rootView: rootView)
        // borderlessにしないとdeactivateServerが呼ばれてしまう
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        backgroundColor = .clear
        contentViewController = viewController
        // フルキーボードアクセスが有効なときに変換パネルが表示されなくなるのを回避
        setAccessibilityElement(false)
    }

    func setCandidates(_ candidates: CurrentCandidates, selected: Candidate?) {
        viewModel.selected = selected
        viewModel.candidates = candidates
    }

    func setSystemAnnotation(_ systemAnnotation: String, for word: Word.Word) {
        viewModel.systemAnnotations[word] = systemAnnotation
    }

    func setCursorPosition(_ cursorPosition: NSRect) {
        self.cursorPosition = cursorPosition
        if let mainScreen = NSScreen.main {
            viewModel.maxWidth = mainScreen.visibleFrame.size.width - cursorPosition.origin.x
        }
    }

    func setShowAnnotationPopover(_ showAnnotationPopover: Bool) {
        self.viewModel.showAnnotationPopover = showAnnotationPopover
    }

    func setCandidatesFontSize(_ candidatesFontSize: Int) {
        self.viewModel.candidatesFontSize = CGFloat(candidatesFontSize)
    }

    func setAnnotationFontSize(_ annotationFontSize: Int) {
        self.viewModel.annotationFontSize = CGFloat(annotationFontSize)
    }

    /**
     * 表示する。スクリーンからはみ出す位置が指定されている場合は自動で調整する。
     *
     * - 下にはみ出る場合: テキストの上側に表示する
     * - 右にはみ出す場合: スクリーン右端に接するように表示する
     */
    func show(windowLevel: NSWindow.Level) {
        // 原因は特定できてないが特殊な場合 (終了が要求されているときなど?) で下記の分岐がfalseになるケースがあったので対処
        guard let viewController = contentViewController as? NSHostingController<CandidatesView> else {
            logger.error("ビューコントローラの状態が想定と異なるため変換候補パネルを表示できません")
            return
        }
        #if DEBUG
        print("content size = \(viewController.sizeThatFits(in: CGSize(width: Int.max, height: Int.max)))")
        print("intrinsicContentSize = \(viewController.view.intrinsicContentSize)")
        print("frame = \(frame)")
        print("preferredContentSize = \(viewController.preferredContentSize)")
        print("sizeThatFits = \(viewController.sizeThatFits(in: CGSize(width: 10000, height: 10000)))")
        #endif
        var origin = cursorPosition.origin
        let width: CGFloat
        let height: CGFloat
        if case let .panel(words, _, _) = viewModel.candidates {
            width = viewModel.showAnnotationPopover ? viewModel.minWidth + CandidatesView.annotationPopupWidth : viewModel.minWidth
            height = CGFloat(words.count) * viewModel.candidatesLineHeight + CandidatesView.footerHeight
            if viewModel.displayPopoverInLeft {
                origin.x = origin.x - CandidatesView.annotationPopupWidth - CandidatesView.annotationMargin
            }
        } else {
            // FIXME: 短い文のときにはそれに合わせて高さを縮める
            width = viewModel.minWidth
            height = 200
        }
        setContentSize(NSSize(width: width, height: height))
        if let mainScreen = NSScreen.main {
            let visibleFrame = mainScreen.visibleFrame
            if origin.x + width > visibleFrame.minX + visibleFrame.width {
                origin.x = visibleFrame.minX + visibleFrame.width - width
            }
            if origin.y - height < visibleFrame.minY {
                origin.y = cursorPosition.maxY + height
            }
        }
        setFrameTopLeftPoint(origin)
        level = windowLevel
        orderFrontRegardless()
    }
}
