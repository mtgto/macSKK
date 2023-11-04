// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

// いい名前が思いつかなかった。NumberEntry = NumberYomi + NumberCandidateとかにするかも。
struct NumberYomi {
    static let pattern = /#([01234589])/

    // TODO: Stringを作るコストをなくしyomiのSubstringでもっておく。Substringだとユニットテストが書きにくくなるしこれでもいいかも。
    enum Element: Equatable {
        /// 正規表現だと /[0-9]+/ となる文字列。UInt64で収まらない数値はあきらめる
        case number(UInt64)
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

    init?(yomi: String) {
        // 連続する整数と連続する非整数をパースする
        var elements: [Element] = []
        var current = yomi[...]
        while !current.isEmpty {
            let numberString = current.prefix(while: { $0.isNumber })
            if !numberString.isEmpty {
                if let number = UInt64(numberString) {
                    elements.append(.number(number))
                    current = yomi.suffix(from: numberString.endIndex)
                } else {
                    logger.log("巨大な数値が含まれているためパースできませんでした")
                    return nil
                }
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
}

// 数値入りの変換候補
struct NumberCandidate {
    static let pattern = /#([01234589])/
    static let kanjiFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "ja-JP")
        formatter.numberStyle = .spellOut
        return formatter
    }()

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
        if yomi.elements.count != elements.count {
            return nil
        }
        for (i, yomiElement) in yomi.elements.enumerated() {
            switch yomiElement {
            case .number(let number):
                if case .number(let type) = elements[i] {
                    switch type {
                    case 0:
                        result.append(String(number))
                    case 1: // 全角
                        result.append(String(number).toZenkaku())
                    case 2: // 漢数字(位取りあり)
                        result.append(toKanjiString(number: number))
                    case 3: // 漢数字(位取りなし)
                        result.append(Self.kanjiFormatter.string(from: NSNumber(value: number))!)
                    case 4: // 数字部分で辞書を引く
                        // TODO: あとで対応する
                        return nil
                    case 5: // 小切手や手形の金額記入の際用いられる表記
                        // TODO: あとで対応する
                        return nil
                    case 8: // 3桁ごとに区切る
                        result.append(number.formatted(.number))
                    case 9: // 将棋の棋譜入力用
                        if number < 10 || number > 99 || number % 10 == 0 {
                            return nil
                        }
                        result.append(String(number / 10).toZenkaku() + toKanjiString(number: number % 10))
                    default:
                        fatalError("未サポートの数値変換タイプ \(type) が指定されています")
                    }
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

    func toKanjiString(number: UInt64) -> String {
        if number == 0 {
            return ""
        }
        return toKanjiString(number: number / 10) + ["〇", "一", "二", "三", "四", "五", "六", "七", "八", "九"][Int(number % 10)]
    }
}
