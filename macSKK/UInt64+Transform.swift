// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

extension UInt64 {
    /**
     * 位取りなしの漢数字に変換します
     *
     * 例:
     * - 1024: "一〇二四"
     */
    func toKanji1() -> String {
        var result: String = ""
        var current = self
        while (current > 0) {
            result.append(["〇", "一", "二", "三", "四", "五", "六", "七", "八", "九"][Int(current % 10)])
            current /= 10
        }
        return String(result.reversed())
    }

    /**
     * 位取りありの漢数字に変換します
     *
     * 例:
     * - 1024: "千二十四"
     */
    func toKanji2() -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "ja-JP")
        formatter.numberStyle = .spellOut
        return formatter.string(from: NSNumber(value: self))!
    }
}
