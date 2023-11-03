// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// 見出し語の注釈
struct Annotation: Equatable {
    static let userDictId: FileDict.ID = NSLocalizedString("User Dictionary", comment: "ユーザー辞書")
    /// 注釈がつけられた辞書のID。現状はユーザー辞書以外はファイル名になっておりSKK-JISYO.Lなどになる。
    let dictId: FileDict.ID
    let text: String
}

/// 辞書に登録する言葉。
///
/// - NOTE: 将来プログラム辞書みたいな機能が増えるかもしれない。
struct Word: Hashable {
    typealias Word = String
    let word: Word
    let annotation: Annotation?

    init(_ word: Self.Word, annotation: Annotation? = nil) {
        self.word = word
        self.annotation = annotation
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(word)
    }
}

/// 複数の辞書から引いた、辞書ごとの注釈をもつことが可能なWord。
struct ReferredWord: Hashable {
    /**
     * 辞書に登録されている読み。
     * 数値変換の場合辞書上は "だい#1" のように登録されているが、この値は "だい5" のように実際のユーザー入力によるもの。
     */
    let yomi: String
    /**
     * 辞書に登録されている変換結果。
     * ただし数値変換の場合、辞書には "第#1" のように登録されているが "第5" のようにユーザー入力で補完されている。
     */
    let word: Word.Word
    /**
     * 変換結果の辞書上での表記。現在は数値変換時のみ使用する。
     * "第#1" のような変換フォーマットを表す表記がされる。
     */
    let originalWord: String?
    private(set) var annotations: [Annotation]

    init(yomi: String, word: Word.Word, annotations: [Annotation] = [], originalWord: String? = nil) {
        self.yomi = yomi
        self.word = word
        self.annotations = annotations
        self.originalWord = originalWord
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(word)
    }

    /// 注釈を追加する。すでに同じテキストをもつ注釈があれば追加されない。
    mutating func appendAnnotation(_ annotation: Annotation) {
        if annotations.allSatisfy({ $0.text != annotation.text }) {
            annotations.append(annotation)
        }
    }
}
