// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

fileprivate enum MergeError: Error, LocalizedError {
    case invalidArgument
}

/**
 * 変換候補
 */
struct Candidate: Hashable {
    /**
     * 辞書上での表記
     */
    struct Original: Hashable {
        /**
         * 辞書上の見出し語の表記。
         * 数値変換の場合 "だい#" のような数値部分を "#" で表す表記がされている。
         */
        let midashi: String
        /**
         * 辞書上の変換結果の表記。
         * 数値変換の場合 "第#1" のような変換フォーマットを表す表記がされている。
         */
        let word: Word.Word
    }

    /**
     * 変換結果。数値変換の場合は例外あり。
     * 数値変換の場合、辞書には "第#1" のように登録されているが "第5" のようにユーザー入力で置換されている。
     */
    let word: Word.Word

    /**
     * 辞書上の表記。現在は数値変換時のみ設定される。
     */
    let original: Original?

    /**
     * 注釈。複数の辞書によるものがあればまとめられている。
     */
    private(set) var annotations: [Annotation]

    /**
     * 確定時にユーザー辞書に保存するべきかどうか。
     * デフォルトはtrue。日付変換の場合はfalse。
     * プライベートモード時はこの値にかかわらず保存されない。
     */
    let saveToUserDict: Bool


    /**
     * 辞書に登録されている読み。
     */
    func toMidashiString(yomi: String) -> String {
        original?.midashi ?? yomi
    }

    /**
     * 辞書に登録されている変換候補。
     */
    var candidateString: String {
        original?.word ?? word
    }

    init(_ word: Word.Word, annotations: [Annotation] = [], original: Original? = nil, saveToUserDict: Bool = true) {
        self.word = word
        self.annotations = annotations
        self.original = original
        self.saveToUserDict = saveToUserDict
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(word)
    }

    /**
     * 同じ変換候補を注釈をマージして返す。
     *
     * 引数と変換結果が同じでない場合はMergeErrorを返す。
     *
     * saveToUserDictは今のところ次の仕様とする
     * - self, otherのsaveToUserDictが同じ値ならその値
     * - self, otherのsaveToUserDictが違う値ならtrue
     */
    func merge(_ other: Candidate) throws -> Candidate {
        guard word == other.word else {
            throw MergeError.invalidArgument
        }
        let annotations = other.annotations.reduce(annotations) { result, annotation in
            if result.allSatisfy( { $0.text != annotation.text } ) {
                return result + [annotation]
            } else {
                return result
            }
        }

        return Candidate(word,
                         annotations: annotations,
                         original: original,
                         saveToUserDict: saveToUserDict || other.saveToUserDict)
    }
}

