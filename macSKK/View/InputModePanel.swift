// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Cocoa

/// 入力モードをフローティングモーダルで表示するパネル
@MainActor
class InputModePanel: NSPanel {
    private let imageView: NSImageView
    private let imageSize: CGSize

    init() {
        imageSize = CGSize(width: 32, height: 32)
        imageView = NSImageView(frame: .zero)
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        imageView.imageScaling = .scaleProportionallyUpOrDown
        backgroundColor = .clear
        isOpaque = false
        ignoresMouseEvents = true
        hasShadow = false
        contentView = imageView
        setContentSize(imageSize)
    }

    func show(at point: NSPoint, mode: InputMode, privateMode: Bool, windowLevel: NSWindow.Level) {
        // 画像の高さ分だけ下にずらす
        let origin = NSPoint(x: point.x, y: point.y - imageSize.height)
        let rect = NSRect(origin: origin, size: imageSize)
        setFrame(rect, display: true)
        level = windowLevel
        switch mode {
        case .hiragana:
            imageView.image = NSImage(named: privateMode ? "icon-hiragana-locked" : "icon-hiragana")
        case .katakana:
            imageView.image = NSImage(named: privateMode ? "icon-katakana-locked" : "icon-katakana")
        case .hankaku:
            imageView.image = NSImage(named: privateMode ? "icon-hankaku-locked" : "icon-hankaku")
        case .eisu:
            imageView.image = NSImage(named: privateMode ? "icon-eisu-locked" : "icon-eisu")
        case .direct:
            imageView.image = NSImage(named: privateMode ? "icon-direct-locked" : "icon-direct")
        }

        alphaValue = 1.0
        // Note: orderFront(nil) だと "Warning: Window NSWindow 0x13b72dbe0 ordered front from a non-active application
        // and may order beneath the active application's windows." のようなエラーがConsole.appに出力される
        // orderFrontRegardlessだとそのようなログが出ない
        orderFrontRegardless()
        // フェードアウト
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 2.0
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().alphaValue = 0.0
        }
    }
}
