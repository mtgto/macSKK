// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Cocoa
import SwiftUI

/// 入力モードをフローティングモーダルで表示するパネル
@MainActor
class InputModePanel: NSPanel {
    private let viewModel: InputModeViewModel
    private let viewSize: CGSize
    /// フェードアウト中に再表示されたとき、古いフェードアウトの完了で新しい表示を消さないための世代
    private var showGeneration: UInt = 0

    init() {
        viewSize = CGSize(width: 33, height: 24)
        viewModel = InputModeViewModel(inputMode: .hiragana, privateMode: false)
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        backgroundColor = .clear
        isOpaque = false
        ignoresMouseEvents = true
        hasShadow = false
        let hostingController = NSHostingController(rootView: InputModeView(viewModel: viewModel))
        contentViewController = hostingController
        setContentSize(viewSize)
    }

    func updateColorSets(_ colorSets: [InputMode: InputModeColorSet]) {
        viewModel.inputModeColorSets = colorSets
    }

    func show(at point: NSPoint, mode: InputMode, privateMode: Bool, windowLevel: NSWindow.Level) {
        // 画像の高さ分だけ下にずらす
        let origin = NSPoint(x: point.x, y: point.y - viewSize.height)
        let rect = NSRect(origin: origin, size: viewSize)
        setFrame(rect, display: true)
        level = windowLevel
        viewModel.inputMode = mode
        viewModel.privateMode = privateMode

        alphaValue = 1.0
        // Note: orderFront(nil) だと "Warning: Window NSWindow 0x13b72dbe0 ordered front from a non-active application
        // and may order beneath the active application's windows." のようなエラーがConsole.appに出力される
        // orderFrontRegardlessだとそのようなログが出ない
        orderFrontRegardless()
        // フェードアウトしたらorderOutする。
        // 残しておくと最初に表示した操作スペースに居続け、別の操作スペースで前面に出しても表示されない
        showGeneration &+= 1
        let generation = showGeneration
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 2.0
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().alphaValue = 0.0
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.showGeneration == generation else { return }
                self.orderOut(nil)
            }
        }
    }
}
