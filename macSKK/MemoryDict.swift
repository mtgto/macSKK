// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// 実ファイルをもたないSKK辞書
struct MemoryDict: DictProtocol {
    private(set) var entries: [String: [Word]]

    init(dictId: FileDict.ID, source: String) throws {
        var dict: [String: [Word]] = [:]
        let pattern = try Regex(#"^(\S+) (/(?:[^/\n\r]+/)+)$"#).anchorsMatchLineEndings()
        for match in source.matches(of: pattern) {
            guard let word = match.output[1].substring else { continue }
            guard let wordsText = match.output[2].substring else { continue }
            let words = wordsText.split(separator: Character("/")).map { word -> Word in
                let words = word.split(separator: Character(";"), maxSplits: 1)
                let annotation = words.count == 2 ? Annotation(dictId: dictId, text: Self.decode(String(words[1]))) : nil
                return Word(Self.decode(String(words[0])), annotation: annotation)
            }
            dict[String(word)] = words
        }
        entries = dict
    }

    init(entries: [String: [Word]]) {
        self.entries = entries
    }

    // MARK: DictProtocol
    func refer(_ yomi: String) -> [Word] {
        return entries[yomi] ?? []
    }

    /// 辞書にエントリを追加する。
    ///
    /// - Parameters:
    ///   - yomi: SKK辞書の見出し。複数のひらがな、もしくは複数のひらがな + ローマ字からなる文字列
    ///   - word: SKK辞書の変換候補。
    mutating func add(yomi: String, word: Word) {
        if var words = entries[yomi] {
            let index = words.firstIndex { $0.word == word.word }
            if let index {
                words.remove(at: index)
            }
            entries[yomi] = [word] + words
        } else {
            entries[yomi] = [word]
        }
    }

    /// 辞書からエントリを削除する。
    ///
    /// 辞書にないエントリ (ファイル辞書) の削除は無視されます。
    ///
    /// - Parameters:
    ///   - yomi: SKK辞書の見出し。複数のひらがな、もしくは複数のひらがな + ローマ字からなる文字列
    ///   - word: SKK辞書の変換候補。
    /// - Returns: エントリを削除できたかどうか
    mutating func delete(yomi: String, word: Word.Word) -> Bool {
        if var words = entries[yomi] {
            if let index = words.firstIndex(where: { $0.word == word }) {
                words.remove(at: index)
                entries[yomi] = words
                return true
            }
        }
        return false
    }

    static func decode(_ word: String) -> String {
        if word.hasPrefix(#"(concat ""#) && word.hasSuffix(#"")"#) {
            return String(word.dropFirst(9).dropLast(2).replacingOccurrences(of: "\\057", with: "/"))
        } else {
            return word
        }
    }
}
