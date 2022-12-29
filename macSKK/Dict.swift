// SPDX-FileCopyrightText: 2022 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/**
 * 辞書に登録する言葉。
 *
 * @note 将来プログラム辞書みたいな機能が増えるかもしれない。
 */
struct Word {
    let word: String
    let annotation: String?
}

struct Dict {
    let words: [String: [Word]]

    init(contentsOf url: URL, encoding: String.Encoding = .utf8) throws {
        let source = try String(contentsOf: url, encoding: encoding)
        try self.init(source: source)
    }
    
    init(source: String) throws {
        var dict: [String: [Word]] = [:]
        let pattern = try NSRegularExpression(pattern: #"^(\S+) (/(?:[^/^\n^\r]+/)+)$"#, options: [.anchorsMatchLines])
        let results = pattern.matches(in: source, range: NSRange(source.startIndex..<source.endIndex, in: source))
        results.forEach { result in
            if let wordRange = Range(result.range(at: 1), in: source) {
                let word = String(source[wordRange])
                if let wordsRange = Range(result.range(at: 2), in: source) {
                    let words = source[wordsRange].split(separator: Character("/")).map { word -> Word in
                        let words = word.split(separator: Character(";"), maxSplits: 1)
                        let annotation = words.count == 2 ? Dict.decode(String(words[1])) : nil
                        return Word(word: Dict.decode(String(words[0])), annotation: annotation)
                    }
                    dict[word] = words
                }
            }
        }
        self.words = dict
    }
    
    static func decode(_ word: String) -> String {
        if word.hasPrefix(#"(concat ""#) && word.hasSuffix(#"")"#) {
            return String(word.dropFirst(9).dropLast(2).replacingOccurrences(of: "\\057", with: "/"))
        } else {
            return word
        }
    }
}
