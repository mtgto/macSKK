// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

extension Character {
    /**
     * アルファベットで構成されているかを返す。
     */
    var isAlphabet: Bool {
        "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ".contains(self)
    }

    var isNumber: Bool {
        "0123456789".contains(self)
    }

    /**
     * ひらがなで構成されているかを返す。
     */
    var isHiragana: Bool {
        guard let first = self.unicodeScalars.first else { return false }
        return 0x3041 <= first.value && first.value <= 0x309f
    }
}
