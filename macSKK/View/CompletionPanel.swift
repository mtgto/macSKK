// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Cocoa
import SwiftUI

class CompletionPanel: NSPanel {
    let viewModel: CompletionViewModel

    /**
     * - Parameters:
     *   - candidatesFontSize: 変換候補のフォントサイズ
     *   - annotationFontSize: 注釈のフォントサイズ。注釈は補完表示では表示してないのでなくてもいいかも?
     */
    init(candidatesFontSize: Int, annotationFontSize: Int) {
        viewModel = CompletionViewModel(completion: .yomi(""),
                                        candidatesFontSize: candidatesFontSize,
                                        annotationFontSize: annotationFontSize)
        let rootView = CompletionView(viewModel: viewModel)
        let viewController = NSHostingController(rootView: rootView)
        super.init(contentRect: .zero, styleMask: [.nonactivatingPanel], backing: .buffered, defer: true)
        contentViewController = viewController
    }

    func show(at cursorPoint: NSRect, windowLevel: NSWindow.Level) {
        var origin = cursorPoint.origin
        let width: CGFloat
        let height: CGFloat
        if case let .panel(words, _, _) = viewModel.candidatesViewModel.candidates {
            switch Global.candidateListDirection.value {
            case .vertical:
                width = viewModel.candidatesViewModel.minWidth
                height = CGFloat(words.count) * viewModel.candidatesViewModel.candidatesLineHeight + CompletionView.footerHeight
            case .horizontal:
                width = viewModel.candidatesViewModel.minWidth
                height = viewModel.candidatesViewModel.candidatesLineHeight + CompletionView.footerHeight
            }
        } else {
            // FIXME: 短い文のときにはそれに合わせて高さを縮める
            width = viewModel.candidatesViewModel.minWidth
            height = 200
        }
        setContentSize(NSSize(width: width, height: height))
        if let mainScreen = NSScreen.main {
            let visibleFrame = mainScreen.visibleFrame
            if origin.x + width > visibleFrame.minX + visibleFrame.width {
                origin.x = visibleFrame.minX + visibleFrame.width - width
            }
            // 1ピクセルの余白を設ける
            if origin.y - height < visibleFrame.minY {
                origin.y = origin.y + cursorPoint.height + height + 1
            } else {
                origin.y = origin.y - 1
            }
        }
        setFrameTopLeftPoint(origin)
        level = windowLevel
        orderFrontRegardless()
    }
}
