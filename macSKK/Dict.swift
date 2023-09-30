// SPDX-FileCopyrightText: 2022 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// 辞書を引くときに優先するエントリを指定するオプション
enum DictPreferringOption {
    /// 接頭辞を優先して返す
    case prefix
    /// 接尾辞を優先して返す
    case suffix
}

protocol DictProtocol {
    /**
     * 辞書を引き変換候補順に返す
     *
     * - Parameters:
     *   - yomi: SKK辞書の見出し。複数のひらがな、もしくは複数のひらがな + ローマ字からなる文字列
     *   - option: 辞書を引くときに接頭辞や接尾辞を優先するかどうか。nilなら優先なし
     */
    func refer(_ yomi: String, option: DictPreferringOption?) -> [Word]

    /**
     * 辞書にエントリを追加する。
     *
     * - Parameters:
     *   - yomi: SKK辞書の見出し。複数のひらがな、もしくは複数のひらがな + ローマ字からなる文字列
     *   - word: SKK辞書の変換候補。
     */
    mutating func add(yomi: String, word: Word)

    /**
     * 辞書からエントリを削除する。
     *
     * 辞書にないエントリ (ファイル辞書) の削除は無視されます。
     *
     * - Parameters:
     *   - yomi: SKK辞書の見出し。複数のひらがな、もしくは複数のひらがな + ローマ字からなる文字列
     *   - word: SKK辞書の変換候補。
     * - Returns: エントリを削除できたかどうか
     */
    mutating func delete(yomi: String, word: Word.Word) -> Bool

    /**
     * 現在入力中のprefixに続く入力候補を1つ返す。見つからなければnilを返す。
     *
     * 以下のように補完候補を探します。
     * ※将来この仕様は変更する可能性が大いにあります。
     *
     * - prefixが空文字列ならnilを返す
     * - ユーザー辞書の送りなしの読みのうち、最近変換したものから選択する。
     * - prefixと読みが完全に一致する場合は補完候補とはしない
     */
    func findCompletion(prefix: String) -> String?
}
