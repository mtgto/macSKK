// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct InputModeColorSet {
    var textColor: Color
    var backgroundColor: Color

    init?(_ dictionary: [String: Any]) {
        guard let textColorString = dictionary["textColor"] as? String,
              let textColor = ColorEncoding.decode(textColorString),
              let backgroundColorString = dictionary["backgroundColor"] as? String,
              let backgroundColor = ColorEncoding.decode(backgroundColorString)
        else { return nil }
        self.textColor = textColor
        self.backgroundColor = backgroundColor
    }

    init(textColor: Color, backgroundColor: Color) {
        self.textColor = textColor
        self.backgroundColor = backgroundColor
    }

    func encode() -> [String: Any] {
        var dict: [String: Any] = [:]
        if let textColorString = ColorEncoding.encode(textColor) {
            dict["textColor"] = textColorString
        }
        if let backgroundColorString = ColorEncoding.encode(backgroundColor) {
            dict["backgroundColor"] = backgroundColorString
        }
        return dict
    }

    static let defaultColorSet = InputModeColorSet(textColor: .black, backgroundColor: .white)
}
