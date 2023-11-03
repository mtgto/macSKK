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
