// SPDX-FileCopyrightText: 2022 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// 辞書に登録する言葉。
///
/// - NOTE: 将来プログラム辞書みたいな機能が増えるかもしれない。
struct Word: Hashable {
    let word: String
    let annotation: String?

    init(_ word: String, annotation: String? = nil) {
        self.word = word
        self.annotation = annotation
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(word)
    }
}

protocol DictProtocol {
    /// 辞書を引き変換候補順に返す
    func refer(_ word: String) -> [Word]
}

struct FileDict: DictProtocol {
    let fileURL: URL
    let entries: [String: [Word]]
    
    init(contentsOf fileURL: URL, encoding: String.Encoding) throws {
        self.fileURL = fileURL
        let source = try String(contentsOf: fileURL, encoding: encoding)
        let memoryDict = try MemoryDict(source: source)
        entries = memoryDict.entries
    }

    // MARK: DictProtocol
    func refer(_ word: String) -> [Word] {
        return entries[word] ?? []
    }
}

/// 実ファイルをもたない辞書
struct MemoryDict: DictProtocol {
    let entries: [String: [Word]]

    init(source: String) throws {
        var dict: [String: [Word]] = [:]
        let pattern = try Regex(#"^(\S+) (/(?:[^/\n\r]+/)+)$"#).anchorsMatchLineEndings()
        for match in source.matches(of: pattern) {
            guard let word = match.output[1].substring else { continue }
            guard let wordsText = match.output[2].substring else { continue }
            let words = wordsText.split(separator: Character("/")).map { word -> Word in
                let words = word.split(separator: Character(";"), maxSplits: 1)
                let annotation = words.count == 2 ? Self.decode(String(words[1])) : nil
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
