// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

final class InputModeViewModel: ObservableObject {
    @Published var privateMode: Bool
    @Published var inputMode: InputMode
    @Published var inputModeColorSets: [InputMode: InputModeColorSet]

    var primary: Color { inputModeColorSets[inputMode]?.textColor ?? .black }
    var background: Color { inputModeColorSets[inputMode]?.backgroundColor ?? .white }

    init(inputMode: InputMode, privateMode: Bool, inputModeColorSets: [InputMode: InputModeColorSet] = [:]) {
        self.inputMode = inputMode
        self.privateMode = privateMode
        self.inputModeColorSets = inputModeColorSets
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
