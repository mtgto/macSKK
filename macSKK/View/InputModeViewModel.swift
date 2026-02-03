// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

final class InputModeViewModel: ObservableObject {
    @Published var primary: Color
    @Published var background: Color
    @Published var privateMode: Bool
    @Published var inputMode: InputMode

    init(primary: Color, background: Color, inputMode: InputMode, privateMode: Bool) {
        self.primary = primary
        self.background = background
        self.inputMode = inputMode
        self.privateMode = privateMode
    }

    var imageForInputMode: String {
        switch inputMode {
        case .hiragana:
            return "mode-hiragana"
        case .katakana:
            return "mode-katakana"
        case .hankaku:
            return "mode-hankaku"
        case .eisu:
            return "mode-eisu"
        case .direct:
            return "mode-direct"
        }
    }
}
