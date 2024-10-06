// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/**
 * 数値変換用のユーザーが入力した読み部分。"だい1" のような入力を受け取り、整数部分と非整数部分に分ける。
 */
struct NumberYomi {
    // TODO: Stringを作るコストをなくしyomiのSubstringでもっておく。Substringだとユニットテストが書きにくくなるしこれでもいいかも。
    enum Element: Equatable {
        /// 正規表現だと /[0-9]+/ となる文字列。UInt64で収まらない数値はあきらめる
        case number(UInt64)
        /// ``number`` 以外
        case other(String)
    }

    let elements: [Element]

    /**
     * ユーザーが入力した読み部分を受け取り初期化する。
     *
     * - Returns: 整数が一つも含まれない (整数が異常に巨大な場合を含む) ときは nil。
     */
    init?(_ yomi: String) {
        // 連続する整数と連続する非整数をパースする
        var elements: [Element] = []
        var current = yomi[...]
        var containsNumber: Bool = false
        while !current.isEmpty {
            let numberString = current.prefix(while: { $0.isNumber })
            if !numberString.isEmpty {
                if let number = UInt64(numberString) {
                    elements.append(.number(number))
                    current = yomi.suffix(from: numberString.endIndex)
                    containsNumber = true
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
        if !containsNumber {
            return nil
        }
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
     * elementsから数値要素だけを取り出します
     */
    var numberElements: [UInt64] {
        elements.compactMap {
            switch $0 {
            case .number(let number):
                return number
            default:
                return nil
            }
        }
    }
}

// 数値入りの変換候補
struct NumberCandidate {
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
            if let match = try /#([01234589])/.firstMatch(in: current) {
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
        var yomiNumbers = yomi.numberElements
        let candidateNumberCount = elements.reduce(0, { count, element in
            if case .number = element {
                return count + 1
            } else {
                return count
            }
        })
        // 読みと変換候補で数値情報の数が不一致
        if yomiNumbers.count != candidateNumberCount {
            return nil
        }
        for element in elements {
            if case .number(let type) = element {
                let number = yomiNumbers.removeFirst()
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
            } else if case .other(let other) = element {
                result.append(other)
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
