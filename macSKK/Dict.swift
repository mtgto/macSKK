// SPDX-FileCopyrightText: 2022 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// 辞書を引くときに指定する特殊なエントリの種類を指定するオプション
enum DictReferringOption {
    /// 接頭辞を返す
    case prefix
    /// 接尾辞を返す
    case suffix
    /// 送り仮名ブロック。引数は例えば「大き」なら「き」、「行った」なら「った」のような送り仮名部分
    case okuri(String)
}

protocol DictProtocol {
    /**
     * 辞書を引き変換候補順に返す
     *
     * optionが設定されている場合は通常のエントリは検索しない
     *
     * - Parameters:
     *   - yomi: SKK辞書の見出し。複数のひらがな、もしくは複数のひらがな + ローマ字からなる文字列
     *   - option: 辞書を引くときに接頭辞、接尾辞や送り仮名ブロックから検索するかどうか。nilなら通常のエントリから検索する
     */
    @MainActor func refer(_ yomi: String, option: DictReferringOption?) -> [Word]

    /**
     * 辞書を逆引きし、最初に見つかった読みを返す
     */
    @MainActor func reverseRefer(_ word: String) -> String?

    /**
     * 辞書にエントリを追加する。
     *
     * - Parameters:
     *   - yomi: SKK辞書の見出し。複数のひらがな、もしくは複数のひらがな + ローマ字からなる文字列
     *   - word: SKK辞書の変換候補。
     */
    @MainActor mutating func add(yomi: String, word: Word)

    /**
     * 辞書に最も古く変換したものとしてエントリを追加する。既にある変換候補は動かさない。
     *
     * 同じ読みがあれば変換候補の末尾に追加し、なければ読みを最も古く変換したものとして追加する。
     * 他の端末で「すべて同期」したときに受け取る、変換した日時がわからない変換候補を反映するのに使う。
     *
     * - Parameters:
     *   - yomi: SKK辞書の見出し。複数のひらがな、もしくは複数のひらがな + ローマ字からなる文字列
     *   - word: SKK辞書の変換候補。
     */
    @MainActor mutating func addAsOldest(yomi: String, word: Word)

    /**
     * 辞書からエントリを削除する。
     *
     * 辞書にないエントリ (ファイル辞書) の削除は無視される。
     * 送り仮名ブロックつきの同じ変換候補がある場合は `word.okuri` が一致する候補だけを削除する。
     *
     * - Parameters:
     *   - yomi: SKK辞書の見出し。複数のひらがな、もしくは複数のひらがな + ローマ字からなる文字列
     *   - word: SKK辞書の変換候補。
     * - Returns: エントリを削除できたかどうか
     */
    @MainActor mutating func delete(yomi: String, word: Word) -> Bool

    /**
     * 現在入力中のprefixに続く入力候補を返す。見つからなければ空配列を返す。
     *
     * 以下のように補完候補を探します。
     * ※将来この仕様は変更する可能性が大いにあります。
     *
     * - prefixが空文字列なら空配列を返す
     * - ユーザー辞書の送りなしの読みのうち、最近変換したものから選択する。
     * - prefixと読みが完全に一致する場合は補完候補とはしない
     * - 数値変換用の読みは補完候補としない
     */
    @MainActor func findCompletions(prefix: String) -> [String]

    /**
     * この辞書から返した変換候補をユーザー辞書に保存するかどうか
     */
    var saveToUserDict: Bool { get }
}
