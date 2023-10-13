// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

// いい名前が思いつかなかった。NumberEntry = NumberYomi + NumberCandidateとかにするかも。
struct NumberYomi {
    static let pattern = /#([01234589])/

    // TODO: Stringを作るコストをなくしyomiのSubstringでもっておく。ちょっとユニットテストがかきにくくなるしこれでもいいかも。
    enum Element: Equatable {
        /// 正規表現だと /[0-9]+/ となる文字列。巨大な整数の可能性があるのでStringのままもつ
        case number(String)
        /// ``number`` 以外
        case other(String)
    }

    let elements: [Element]

    var containsNumber: Bool {
        elements.contains { element in
            if case .number = element {
                return true
            } else {
                return false
            }
        }
    }

    init(yomi: String) {
        // 連続する整数と連続する非整数をパースする
        var elements: [Element] = []
        var current = yomi[...]
        while !current.isEmpty {
            let number = current.prefix(while: { $0.isNumber })
            if !number.isEmpty {
                elements.append(.number(String(number)))
                current = yomi.suffix(from: number.endIndex)
            }
            let other = current.prefix(while: { !$0.isNumber })
            if !other.isEmpty {
                elements.append(.other(String(other)))
                current = yomi.suffix(from: other.endIndex)
            }
        }
        self.elements = elements
    }

    /**
     * 辞書の見出し語となる文字列に変換して返す
     */
    func toMidashiString() -> String {
        return elements.map { element in
            switch element {
            case .number:
                return "#"
            case .other(let string):
                return string
            }
        }.joined()
    }

    /**
     * 数値入りの変換候補を読みに含まれる数値の情報を使って文字列に変換します
     *
     * もし読みと変換候補で数値情報の数に差があったり文字列に変換できない数値を含む場合はnilを返します
     */
    func toCandidateString(candidate: String) -> String? {
        var result: String = ""
        for element in elements {
            switch element {
            case .other:
                break
            case .number(let number):
                break
            }
        }
        return nil
    }
}

// 数値入りの変換候補
struct NumberCandidate {
    static let pattern = /#([01234589])/

    enum Element: Equatable {
        /// 正規表現だと /#[01234589]/ となる文字列。引数は数値部分
        case number(Int)
        /// ``number`` 以外
        case other(String)
    }

    let elements: [Element]

    init(yomi: String) throws {
        var result: [Element] = []
        var current = yomi[...]
        while !current.isEmpty {
            if let match = try Self.pattern.firstMatch(in: current) {
                let prefix = current.prefix(upTo: match.range.lowerBound)
                if !prefix.isEmpty {
                    result.append(.other(String(prefix)))
                }
                if let type = Int(match.1) {
                    result.append(.number(type))
                }
                current = current.suffix(from: match.range.upperBound)
            } else {
                break
            }
        }
        if !current.isEmpty {
            result.append(.other(String(current)))
        }
        self.elements = result
    }

    /**
     * 数値入りの変換候補を読みに含まれる数値の情報を使って文字列に変換します
     *
     * もし読みと変換候補で数値情報の数に差があったり文字列に変換できない数値を含む場合はnilを返します
     */
    func toString(yomi: NumberYomi) -> String? {
        var result: String = ""
        for (i, yomiElement) in yomi.elements.enumerated() {
            switch yomiElement {
            case .number(let number):
                if case .number(let type) = elements[i] {
                    result.append(number)
                } else {
                    return nil
                }
            case .other:
                if case .other(let other) = elements[i] {
                    result.append(other)
                } else {
                    return nil
                }
            }
        }
        return result
    }
}
