// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

// いい名前が思いつかなかった。NumberEntry = NumberYomi + NumberCandidateとかにするかも。
enum Yomi: Equatable {
    /// 正規表現だと /[0-9]+/ となる文字列。巨大な整数の可能性があるのでStringのままもつ
    case number(String)
    /// ``number`` 以外
    case other(String)

    static func parse(_ yomi: String) -> [Yomi] {
        var result: [Yomi] = []
        var current = Substring(stringLiteral: yomi)
        while !current.isEmpty {
            let number = current.prefix(while: { $0.isNumber })
            if !number.isEmpty {
                result.append(.number(String(number)))
                current = yomi.suffix(from: number.endIndex)
            }
            let other = current.prefix(while: { !$0.isNumber })
            if !other.isEmpty {
                result.append(.other(String(other)))
                current = yomi.suffix(from: other.endIndex)
            }
        }
        return result
    }
}
