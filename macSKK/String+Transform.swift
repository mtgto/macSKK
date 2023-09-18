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

    func toHankaku() -> String {
        guard let converted = applyingTransform(.fullwidthToHalfwidth, reverse: false) else {
            fatalError("半角への変換に失敗: \"\(self)\"")
        }
        return converted
    }

    func toHiragana() -> String {
        // 「ゔ」は使わないほうが主流と思われるため特別扱いしてる
        guard
            let converted = replacingOccurrences(of: "ヴ", with: "う゛").applyingTransform(
                .hiraganaToKatakana, reverse: true)
        else {
            fatalError("ひらがなへの変換に失敗: \"\(self)\"")
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

    /**
     * アルファベットだけで構成されているかを返す。
     *
     * どちらかに決めないといけないので空文字列はtrue
     */
    var isAlphabet: Bool { self.allSatisfy { $0.isAlphabet } }

    /**
     * 自身が見出し語のとき、送り仮名ありの見出し語かどうかを返す。
     *
     * どちらかに決めないといけないので一文字もしくは空文字列はfalse
     */
    var isOkuriAri: Bool {
        if let first = first, let last = last, count > 1 {
            return last.isAlphabet && !first.isAlphabet
        }
        return false
    }
}
