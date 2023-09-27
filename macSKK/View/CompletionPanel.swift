// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Cocoa
import SwiftUI

class CompletionPanel: NSPanel {
    let viewModel: CompletionViewModel

    init() {
        viewModel = CompletionViewModel(completion: "")
        let rootView = CompletionView(viewModel: viewModel)
        let viewController = NSHostingController(rootView: rootView)
        super.init(contentRect: .zero, styleMask: [.nonactivatingPanel], backing: .buffered, defer: true)
        contentViewController = viewController
        level = .floating
    }

    func show(at cursorPosition: NSRect) {
        var origin = cursorPosition.origin
        setFrameTopLeftPoint(origin)
        orderFrontRegardless()
    }
}
