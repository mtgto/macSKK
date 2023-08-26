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

    init(_ word: String, annotation: Annotation? = nil) {
        self.word = word
        self.annotation = annotation
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(word)
    }
}

/// 複数の辞書から引いた、辞書ごとの注釈をもつことが可能なWord。
struct ReferredWord: Equatable, Hashable {
    let word: String
    private(set) var annotations: [Annotation]

    init(_ word: String, annotations: [Annotation] = []) {
        self.word = word
        self.annotations = annotations
    }

    static func ==(lhs: Self, rhs: Self) -> Bool {
        return lhs.word == rhs.word
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
