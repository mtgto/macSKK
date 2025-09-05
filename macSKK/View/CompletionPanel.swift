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
        level = windowLevel
        var origin = cursorPoint.origin

        if let size = contentViewController?.view.frame.size, let mainScreen = NSScreen.main {
            let visibleFrame = mainScreen.visibleFrame
            if origin.x + size.width > visibleFrame.minX + visibleFrame.width {
                origin.x = visibleFrame.minX + visibleFrame.width - size.width
            }
            // 1ピクセルの余白を設ける
            if origin.y - size.height < visibleFrame.minY {
                origin.y = origin.y + size.height + cursorPoint.height + 1
            } else {
                origin.y -= 1
            }
        }
        setFrameTopLeftPoint(origin)
        orderFrontRegardless()
    }
}
