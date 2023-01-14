// SPDX-FileCopyrightText: 2022 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// 辞書に登録する言葉。
///
/// - NOTE: 将来プログラム辞書みたいな機能が増えるかもしれない。
struct Word: Equatable {
    let word: String
    let annotation: String?

    init(_ word: String, annotation: String? = nil) {
        self.word = word
        self.annotation = annotation
    }
}

protocol DictProtocol {
    /// 辞書を引き変換候補順に返す
    func refer(_ word: String) -> [Word]
}

struct Dict: DictProtocol {
    let entries: [String: [Word]]

    init(contentsOf url: URL, encoding: String.Encoding) throws {
        let source = try String(contentsOf: url, encoding: encoding)
        try self.init(source: source)
    }

    init(source: String) throws {
        var dict: [String: [Word]] = [:]
        let pattern = try Regex(#"^(\S+) (/(?:[^/^\n^\r]+/)+)$"#).anchorsMatchLineEndings()
        for match in source.matches(of: pattern) {
            guard let word = match.output[1].substring else { continue }
            guard let wordsText = match.output[2].substring else { continue }
            let words = wordsText.split(separator: Character("/")).map { word -> Word in
                let words = word.split(separator: Character(";"), maxSplits: 1)
                let annotation = words.count == 2 ? Dict.decode(String(words[1])) : nil
                return Word(Dict.decode(String(words[0])), annotation: annotation)
            }
            dict[String(word)] = words
        }
        entries = dict
    }

    init(entries: [String: [Word]]) {
        self.entries = entries
    }

    func refer(_ word: String) -> [Word] {
        return entries[word] ?? []
    }

    static func decode(_ word: String) -> String {
        if word.hasPrefix(#"(concat ""#) && word.hasSuffix(#"")"#) {
            return String(word.dropFirst(9).dropLast(2).replacingOccurrences(of: "\\057", with: "/"))
        } else {
            return word
        }
    }
}
