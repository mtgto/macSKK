// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// 実ファイルをもたないSKK辞書
struct MemoryDict: DictProtocol {
    let entries: [String: [Word]]

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

    static func decode(_ word: String) -> String {
        if word.hasPrefix(#"(concat ""#) && word.hasSuffix(#"")"#) {
            return String(word.dropFirst(9).dropLast(2).replacingOccurrences(of: "\\057", with: "/"))
        } else {
            return word
        }
    }
}
