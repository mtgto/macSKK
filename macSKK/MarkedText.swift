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
     *   - [.markerCompose, .plain("あ\*い")]
     * - Shift-A, I, left-key
     *   - [.markerCompose, .plain("あ"), .cursor, .plain("い")]
     * - Shift-A, space
     *   - [.markerSelect, .emphasize("阿")]
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

        var text: String? {
            switch self {
            case .plain(let text), .emphasized(let text):
                return text
            case .markerCompose, .markerSelect, .cursor:
                return nil
            }
        }
    }
    let elements: [Element]

    init(_ elements: [Element]) {
        self.elements = elements
    }

    func attributedString(_ showMarkedTextMarker: ShowMarkedTextMarker) -> AttributedString {
        let showMarker = resolveShowMarker(showMarkedTextMarker)
        var result = AttributedString()
        for element in elements {
            switch element {
            case .markerCompose:
                if showMarker {
                    result += AttributedString("▽", attributes: .init([.underlineStyle: NSUnderlineStyle.single.rawValue]))
                }
            case .markerSelect:
                if showMarker {
                    result += AttributedString("▼", attributes: .init([.underlineStyle: NSUnderlineStyle.thick.rawValue]))
                }
            case .plain(let text):
                result += AttributedString(text, attributes: .init([.underlineStyle: NSUnderlineStyle.single.rawValue]))
            case .emphasized(let text):
                result += AttributedString(text, attributes: .init([.underlineStyle: NSUnderlineStyle.thick.rawValue]))
            case .cursor:
                result += AttributedString("", attributes: .init([.cursor: NSCursor.iBeam]))
            }
        }
        if !elements.contains(where: { $0 == .cursor }) {
            result += AttributedString("", attributes: .init([.cursor: NSCursor.iBeam]))
        }
        return result
    }

    func cursorRange(_ showMarkedTextMarker: ShowMarkedTextMarker) -> NSRange? {
        var location: Int = 0
        let showMarker = resolveShowMarker(showMarkedTextMarker)
        for element in elements {
            switch element {
            case .markerSelect, .markerCompose:
                if showMarker { location += 1 }
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

    /// showMarkedTextMarkerの設定が.minimalのとき、▽や▼を消すと未確定文字列が空になる場合だけマーカーを表示する。
    /// この挙動が必要な理由は.minimalの説明を参照。
    private func resolveShowMarker(_ showMarkedTextMarker: ShowMarkedTextMarker) -> Bool {
        switch showMarkedTextMarker {
        case .always:
            return true
        case .never:
            return false
        case .minimal:
            // .plainや.emphasizedのテキストが空の場合は未確定文字列が空になるので▽や▼を出す必要がある。
            return elements.compactMap(\.text).allSatisfy(\.isEmpty)
        }
    }
}
