// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

extension Character {
    /**
     * アルファベットだけで構成されているかを返す。
     */
    var isAlphabet: Bool {
        "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ".contains(self)
    }

    var isNumber: Bool {
        "0123456789".contains(self)
    }
}
