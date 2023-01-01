// SPDX-FileCopyrightText: 2022 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

extension String {
    func toZenkaku() -> String {
        guard let converted = applyingTransform(.fullwidthToHalfwidth, reverse: true) else {
            fatalError("全角への変換に失敗: \"\(self)\"")
        }
        return converted
    }

    func toKatakana() -> String {
        guard
            let converted = replacingOccurrences(of: "う゛", with: "ヴ").applyingTransform(
                .hiraganaToKatakana, reverse: false)
        else {
            fatalError("カタカナへの変換に失敗: \"\(self)\"")
        }
        return converted
    }
}
