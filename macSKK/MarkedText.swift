// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import Foundation

protocol MarkedTextProtocol {
    /**
     * 現在の状態をMarkedTextとして出力したときを表す文字列、カーソル位置を返す。
     *
     * 入力文字列に対する応答例:
     * - Shift-A, I
     *   - [.plain("▽あい")]
     * - Shift-A, Shift-I
     *   - [.plain("▽あ\*い")]
     * - Shift-A, I, left-key
     *   - [.plain("▽あ"), .cursor, .plain("い")]
     * - Shift-A, space
     *   - [.emphasize("▼阿")]
     */
    func markedTextElements(inputMode: InputMode) -> [MarkedText.Element]
}

/// 未確定文字列 (下線で表示される) を表すデータ構造。
struct MarkedText: Equatable {
    /// 意味の違う部分文字列ごとの定義。現在のところは下線のスタイルの出し分けにだけ使用する
    enum Element: Equatable {
        /// ▽ のこと。マーカーという名前はddskkに合わせています。
        /// 将来カスタマイズしたときには引数Stringを取るようにするかも。
        case markerCompose
        /// ▼ のこと。
        case markerSelect
        /// 細い下線で表示する文字列。未確定文字列の入力中、"[登録中]" などのカーソルを操作できない文字列など
        case plain(String)
        /// 太い下線で表示する文字列。今選択されている変換候補。
        case emphasized(String)
        /// カーソル
        case cursor

        var attributedString: AttributedString {
            switch self {
            case .markerSelect:
                return Self.plain("▽").attributedString
            case .markerCompose:
                return Self.emphasized("▼").attributedString
            case .plain(let text):
                return AttributedString(text, attributes: .init([.underlineStyle: NSUnderlineStyle.single.rawValue]))
            case .emphasized(let text):
                return AttributedString(text, attributes: .init([.underlineStyle: NSUnderlineStyle.thick.rawValue]))
            case .cursor:
                return AttributedString("", attributes: .init([.cursor: NSCursor.iBeam]))
            }
        }
    }
    let elements: [Element]

    init(_ elements: [Element]) {
        self.elements = elements
    }

    var attributedString: AttributedString {
        if let first = elements.first {
            var result = elements.dropFirst().reduce(first.attributedString, { result, current in
                return result + current.attributedString
            })
            if !elements.contains(where: { $0 == .cursor }) {
                result.append(Element.cursor.attributedString)
            }
            return result
        } else {
            return AttributedString()
        }
    }

    func cursorRange() -> NSRange? {
        var location: Int = 0
        for element in elements {
            switch element {
            case .markerSelect, .markerCompose:
                location += 1
            case .plain(let string):
                location += string.count
            case .emphasized(let string):
                location += string.count
            case .cursor:
                return NSRange(location: location, length: 0)
            }
        }
        return nil
    }
}
