// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Cocoa

/// 入力モードをフローティングモーダルで表示するパネル
class InputModePanel: NSPanel {
    private let imageView: NSImageView
    private let imageSize: CGSize

    init() {
        imageSize = CGSize(width: 32, height: 32)
        imageView = NSImageView(frame: .zero)
        // super.init(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: true)
        super.init(contentRect: .zero, styleMask: [.nonactivatingPanel], backing: .buffered, defer: true)
        imageView.imageScaling = .scaleProportionallyUpOrDown
        backgroundColor = .clear
        isOpaque = false
        ignoresMouseEvents = true
        hasShadow = false
        contentView = imageView
        setContentSize(imageSize)
    }

    func show(at point: NSPoint, mode: InputMode) {
        // 画像の高さ分だけ下にずらす
        let origin = NSPoint(x: point.x, y: point.y - imageSize.height)
        let rect = NSRect(origin: origin, size: imageSize)
        setFrame(rect, display: true)
        level = .floating
        switch mode {
        case .hiragana:
            imageView.image = NSImage(named: "icon-hiragana")
        case .katakana:
            imageView.image = NSImage(named: "icon-katakana")
        case .hankaku:
            imageView.image = NSImage(named: "icon-hankaku")
        case .eisu:
            imageView.image = NSImage(named: "icon-eisu")
        case .direct:
            imageView.image = NSImage(named: "icon-direct")
        }

        alphaValue = 1.0
        // フェードアウト
        orderFront(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 2.0
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().alphaValue = 0.0
        }
    }
}
